package docker

import (
	"archive/tar"
	"compress/gzip"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

type TGZArchiver struct {
	prefix string
}

func NewTGZArchiver() TGZArchiver {
	return TGZArchiver{}
}

func (a TGZArchiver) WithPrefix(prefix string) Archiver {
	a.prefix = prefix
	return a
}

func (a TGZArchiver) Compress(input, output string) error {
	err := os.MkdirAll(filepath.Dir(output), os.ModePerm)
	if err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	file, err := os.Create(output)
	if err != nil {
		return fmt.Errorf("failed to create output file: %w", err)
	}
	defer file.Close()

	gw := gzip.NewWriter(file)
	defer gw.Close()

	tw := tar.NewWriter(gw)
	defer tw.Close()

	info, err := os.Stat(input)
	if err != nil {
		return err
	}

	switch {
	case info.IsDir():
		return a.fromDirectory(input, tw)
	case info.Mode()&fs.ModeType == 0:
		return a.fromFile(input, tw)
	default:
		return errors.New("unknown file type")
	}
}

func (a TGZArchiver) fromDirectory(input string, tw *tar.Writer) error {
	err := filepath.Walk(input, func(path string, info fs.FileInfo, err error) error {
		if err != nil {
			return fmt.Errorf("failed to walk input path: %w", err)
		}

		var link string
		if info.Mode()&fs.ModeSymlink != 0 {
			link, err = os.Readlink(path)
			if err != nil {
				return fmt.Errorf("failed to read symlink: %w", err)
			}

			if !strings.HasPrefix(link, string(filepath.Separator)) {
				link = filepath.Clean(filepath.Join(filepath.Dir(path), link))
			}

			link, err = filepath.Rel(filepath.Dir(path), link)
			if err != nil {
				return fmt.Errorf("failed to find link path relative to path: %w", err)
			}
		}

		rel, err := filepath.Rel(input, path)
		if err != nil {
			return fmt.Errorf("failed to find path relative to input: %w", err)
		}

		header, err := tar.FileInfoHeader(info, link)
		if err != nil {
			return fmt.Errorf("failed to create tar header: %w", err)
		}

		header.Name = filepath.Join(a.prefix, rel)
		header.Uid = 2000
		header.Gid = 2000
		header.Uname = "vcap"
		header.Gname = "vcap"

		err = tw.WriteHeader(header)
		if err != nil {
			return fmt.Errorf("failed to write tar header: %w", err)
		}

		if info.Mode().IsRegular() {
			f, err := os.Open(path)
			if err != nil {
				return fmt.Errorf("failed to open file: %w", err)
			}
			defer f.Close()

			_, err = io.Copy(tw, f)
			if err != nil {
				return fmt.Errorf("failed to copy file: %w", err)
			}
		}

		return nil
	})
	if err != nil {
		return fmt.Errorf("failed to walk input path: %w", err)
	}

	return nil
}

func (a TGZArchiver) fromFile(input string, tw *tar.Writer) error {
	file, err := os.Open(input)
	if err != nil {
		return fmt.Errorf("failed to open file: %w", err)
	}

	zr, err := gzip.NewReader(file)
	if err != nil {
		return fmt.Errorf("failed to read gzip file: %w", err)
	}

	tr := tar.NewReader(zr)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return fmt.Errorf("failed to read tar header: %w", err)
		}

		hdr.Name = filepath.Join(a.prefix, hdr.Name)
		hdr.Uid = 2000
		hdr.Gid = 2000
		hdr.Uname = "vcap"
		hdr.Gname = "vcap"

		err = tw.WriteHeader(hdr)
		if err != nil {
			return fmt.Errorf("failed to write tar header: %w", err)
		}

		if hdr.Typeflag == tar.TypeReg {
			_, err = io.CopyN(tw, tr, hdr.Size)
			if err != nil {
				return fmt.Errorf("failed to copy file: %w", err)
			}
		}
	}

	return nil
}
