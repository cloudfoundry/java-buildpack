package fs

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

// Copy will move a source file or directory to a destination. For directories,
// move will remap relative symlinks ensuring that they align with the
// destination directory. If the destination exists prior to invocation, it
// will be removed.
func Copy(source, destination string) error {
	err := os.Remove(destination)
	if err != nil {
		if !errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("failed to copy: destination exists: %w", err)
		}
	}

	info, err := os.Stat(source)
	if err != nil {
		return err
	}

	if info.IsDir() {
		err = copyDirectory(source, destination)
		if err != nil {
			return err
		}
	} else {
		err = copyFile(source, destination)
		if err != nil {
			return err
		}
	}

	return nil
}

func copyFile(source, destination string) error {
	sourceFile, err := os.Open(source)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destinationFile, err := os.Create(destination)
	if err != nil {
		return err
	}
	defer destinationFile.Close()

	_, err = io.Copy(destinationFile, sourceFile)
	if err != nil {
		return err
	}

	info, err := sourceFile.Stat()
	if err != nil {
		return err
	}

	err = os.Chmod(destination, info.Mode())
	if err != nil {
		return err
	}

	return nil
}

func copyDirectory(source, destination string) error {
	err := filepath.Walk(source, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		path, err = filepath.Rel(source, path)
		if err != nil {
			return err
		}

		switch {
		case info.IsDir():
			err = os.Mkdir(filepath.Join(destination, path), os.ModePerm)
			if err != nil {
				return err
			}

		case (info.Mode() & os.ModeSymlink) != 0:
			err = copyLink(source, destination, path)
			if err != nil {
				return err
			}

		default:
			err = copyFile(filepath.Join(source, path), filepath.Join(destination, path))
			if err != nil {
				return err
			}
		}

		return nil
	})

	if err != nil {
		return err
	}

	return nil
}

func copyLink(source, destination, path string) error {
	link, err := os.Readlink(filepath.Join(source, path))
	if err != nil {
		return err
	}

	err = os.Symlink(link, filepath.Join(destination, path))
	if err != nil {
		return err
	}

	return nil
}
