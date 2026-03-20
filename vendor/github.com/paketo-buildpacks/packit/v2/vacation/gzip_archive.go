package vacation

import (
	"compress/gzip"
	"fmt"
	"io"
)

// A GzipArchive decompresses gzipped files from an input stream.
type GzipArchive struct {
	reader     io.Reader
	components int
	name       string
}

// NewGzipArchive returns a new GzipArchive that reads from inputReader.
func NewGzipArchive(inputReader io.Reader) GzipArchive {
	return GzipArchive{reader: inputReader}
}

// Decompress reads from GzipArchive and writes files into the destination
// specified.
func (gz GzipArchive) Decompress(destination string) error {
	gzr, err := gzip.NewReader(gz.reader)
	if err != nil {
		return fmt.Errorf("failed to create gzip reader: %w", err)
	}

	return NewArchive(gzr).WithName(gz.name).StripComponents(gz.components).Decompress(destination)
}

// StripComponents behaves like the --strip-components flag on tar command
// removing the first n levels from the final decompression destination.
func (gz GzipArchive) StripComponents(components int) GzipArchive {
	gz.components = components
	return gz
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (gz GzipArchive) WithName(name string) GzipArchive {
	gz.name = name
	return gz
}
