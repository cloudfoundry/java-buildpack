package vacation

import (
	"io"
	"os"
	"path/filepath"
)

// An Executable writes an executable files from an input stream to the with a
// file name specified by the option `Executable.WithName()` (or defaults to
// `artifact`) in the destination directory with executable permissions (0755).
type Executable struct {
	reader io.Reader
	name   string
}

// NewExecutable returns a new Executable that reads from inputReader.
func NewExecutable(inputReader io.Reader) Executable {
	return Executable{
		reader: inputReader,
		name:   "artifact",
	}
}

// Decompress copies the reader contents into the destination specified and
// sets executable permissions.
func (e Executable) Decompress(destination string) error {
	file, err := os.Create(filepath.Join(destination, e.name))
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, e.reader)
	if err != nil {
		return err
	}

	err = os.Chmod(filepath.Join(destination, e.name), 0755)
	if err != nil {
		return err
	}

	return nil
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (e Executable) WithName(name string) Executable {
	if name != "" {
		e.name = name
	}
	return e
}
