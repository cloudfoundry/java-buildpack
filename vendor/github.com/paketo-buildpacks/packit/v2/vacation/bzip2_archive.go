package vacation

import (
	"compress/bzip2"
	"io"
)

// A Bzip2Archive decompresses bzip2 files from an input stream.
type Bzip2Archive struct {
	reader     io.Reader
	components int
	name       string
}

// NewBzip2Archive returns a new Bzip2Archive that reads from inputReader.
func NewBzip2Archive(inputReader io.Reader) Bzip2Archive {
	return Bzip2Archive{reader: inputReader}
}

// Decompress reads from Bzip2Archive and writes files into the destination
// specified.
func (bz Bzip2Archive) Decompress(destination string) error {
	return NewArchive(bzip2.NewReader(bz.reader)).WithName(bz.name).StripComponents(bz.components).Decompress(destination)
}

// StripComponents behaves like the --strip-components flag on tar command
// removing the first n levels from the final decompression destination.
func (bz Bzip2Archive) StripComponents(components int) Bzip2Archive {
	bz.components = components
	return bz
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (bz Bzip2Archive) WithName(name string) Bzip2Archive {
	bz.name = name
	return bz
}
