package vacation

import (
	"bufio"
	"fmt"
	"io"

	"github.com/gabriel-vasile/mimetype"
)

type Decompressor interface {
	Decompress(destination string) error
}

// An Archive decompresses tar, gzip, xz, and bzip2 compressed tar, and zip files from
// an input stream.
type Archive struct {
	reader     io.Reader
	components int
	name       string
}

// NewArchive returns a new Archive that reads from inputReader.
func NewArchive(inputReader io.Reader) Archive {
	return Archive{
		reader: inputReader,
	}
}

// Decompress reads from Archive, determines the archive type of the input
// stream, and writes files into the destination specified.
//
// Archive decompression will also handle files that are types
// - "application/x-executable"
// - "text/plain; charset=utf-8"
// - "application/jar"
// - "application/octet-stream"
// and write the contents of the input stream to a file name specified by the
// `Archive.WithName()` option in the destination directory.
func (a Archive) Decompress(destination string) error {
	// Convert reader into a buffered read so that the header can be peeked to
	// determine the type.
	bufferedReader := bufio.NewReader(a.reader)

	// The number 3072 is lifted from the mimetype library and the definition of
	// the constant at the time of writing this functionality is listed below.
	// https://github.com/gabriel-vasile/mimetype/blob/c64c025a7c2d8d45ba57d3cebb50a1dbedb3ed7e/internal/matchers/matchers.go#L6
	header, err := bufferedReader.Peek(3072)
	if err != nil && err != io.EOF {
		return err
	}

	mime := mimetype.Detect(header)

	// This switch case is responsible for determining the decompression strategy
	var decompressor Decompressor
	switch mime.String() {
	case "application/x-tar":
		decompressor = NewTarArchive(bufferedReader).StripComponents(a.components)
	case "application/gzip":
		decompressor = NewGzipArchive(bufferedReader).StripComponents(a.components).WithName(a.name)
	case "application/x-xz":
		decompressor = NewXZArchive(bufferedReader).StripComponents(a.components).WithName(a.name)
	case "application/x-bzip2":
		decompressor = NewBzip2Archive(bufferedReader).StripComponents(a.components).WithName(a.name)
	case "application/zip":
		decompressor = NewZipArchive(bufferedReader).StripComponents(a.components)
	case "application/x-executable":
		decompressor = NewExecutable(bufferedReader).WithName(a.name)
	case "text/plain; charset=utf-8",
		"application/jar",
		"application/octet-stream":
		decompressor = NewNopArchive(bufferedReader).WithName(a.name)
	default:
		return fmt.Errorf("unsupported archive type: %s", mime.String())
	}

	return decompressor.Decompress(destination)
}

// StripComponents behaves like the --strip-components flag on tar command
// removing the first n levels from the final decompression destination.
// Setting this is a no-op for archive types that do not use --strip-components
// (such as zip).
func (a Archive) StripComponents(components int) Archive {
	a.components = components
	return a
}

// WithName provides a way of overriding the name of the file
// that the decompressed file will be copied into.
func (a Archive) WithName(name string) Archive {
	a.name = name
	return a
}
