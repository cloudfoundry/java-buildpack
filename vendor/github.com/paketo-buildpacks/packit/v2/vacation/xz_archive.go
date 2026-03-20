package vacation

import (
	"fmt"
	"io"

	"github.com/ulikunitz/xz"
)

// A XZArchive decompresses xz files from an input stream.
type XZArchive struct {
	reader     io.Reader
	components int
	name       string
}

// NewXZArchive returns a new XZArchive that reads from inputReader.
func NewXZArchive(inputReader io.Reader) XZArchive {
	return XZArchive{reader: inputReader}
}

// Decompress reads from XZArchive and writes files into the destination
// specified.
func (xzArchive XZArchive) Decompress(destination string) error {
	xzr, err := xz.NewReader(xzArchive.reader)
	if err != nil {
		return fmt.Errorf("failed to create xz reader: %w", err)
	}

	return NewArchive(xzr).WithName(xzArchive.name).StripComponents(xzArchive.components).Decompress(destination)
}

// StripComponents behaves like the --strip-components flag on tar command
// removing the first n levels from the final decompression destination.
func (xzArchive XZArchive) StripComponents(components int) XZArchive {
	xzArchive.components = components
	return xzArchive
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (xzArchive XZArchive) WithName(name string) XZArchive {
	xzArchive.name = name
	return xzArchive
}
