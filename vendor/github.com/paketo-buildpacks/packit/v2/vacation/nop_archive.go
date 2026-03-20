package vacation

import (
	"io"
	"os"
	"path/filepath"
)

// A NopArchive implements the common archive interface, but acts as a no-op,
// simply copying the reader to the destination with a file name specified by
// the option `NopArchive.WithName()` (or defaults to `artifact`) in the
// destination directory.
type NopArchive struct {
	reader io.Reader
	name   string
}

// NewNopArchive returns a new NopArchive
func NewNopArchive(r io.Reader) NopArchive {
	return NopArchive{
		reader: r,
		name:   "artifact",
	}
}

// Decompress copies the reader contents into the destination specified.
func (na NopArchive) Decompress(destination string) error {
	file, err := os.Create(filepath.Join(destination, na.name))
	if err != nil {
		return err
	}
	defer file.Close()

	_, err = io.Copy(file, na.reader)
	if err != nil {
		return err
	}

	return nil
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (na NopArchive) WithName(name string) NopArchive {
	if name != "" {
		na.name = name
	}
	return na
}
