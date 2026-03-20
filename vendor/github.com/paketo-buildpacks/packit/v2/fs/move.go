package fs

import (
	"fmt"
	"os"
)

// Move will move a source file or directory to a destination. For directories,
// move will remap relative symlinks ensuring that they align with the
// destination directory. If the destination exists prior to invocation, it
// will be removed. Additionally, the source will be removed once it has been
// copied to the destination.
func Move(source, destination string) error {
	err := Copy(source, destination)
	if err != nil {
		return fmt.Errorf("failed to move: %s", err)
	}

	err = os.RemoveAll(source)
	if err != nil {
		return err
	}

	return nil
}
