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
	level  int
}

func NewTGZArchiver() TGZArchiver {
	return TGZArchiver{level: gzip.DefaultCompression}
}

func (a TGZArchiver) WithPrefix(prefix string) Archiver {
	a.prefix = prefix
	return a
}

// WithCompressionLevel sets the gzip compression level (e.g. gzip.BestSpeed)
// used by Compress. Callers whose input is already compressed, such as the
// buildpacks manager, can trade compression ratio for speed.
func (a TGZArchiver) WithCompressionLevel(level int) TGZArchiver {
	a.level = level
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

	gw, err := gzip.NewWriterLevel(file, a.level)
	if err != nil {
		return fmt.Errorf("failed to create gzip writer: %w", err)
	}

	tw := tar.NewWriter(gw)

	info, err := os.Stat(input)
	if err != nil {
		return err
	}

	switch {
	case info.IsDir():
		err = a.fromDirectory(input, tw)
	case info.Mode()&fs.ModeType == 0:
		err = a.fromFile(input, tw)
	default:
		err = errors.New("unknown file type")
	}
	if err != nil {
		return err
	}

	// Close explicitly (instead of via defer) so flush errors, such as a full
	// disk producing a truncated archive, are not silently discarded before
	// the tarball is published to the shared cache.
	if err := tw.Close(); err != nil {
		return fmt.Errorf("failed to close tar writer: %w", err)
	}

	if err := gw.Close(); err != nil {
		return fmt.Errorf("failed to close gzip writer: %w", err)
	}

	if err := file.Close(); err != nil {
		return fmt.Errorf("failed to close output file: %w", err)
	}

	return nil
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
