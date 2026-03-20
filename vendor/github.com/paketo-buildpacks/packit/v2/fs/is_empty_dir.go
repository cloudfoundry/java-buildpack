package fs

import "os"

// IsEmptyDir checks to see if a directory exists and is empty.
func IsEmptyDir(path string) bool {
	contents, err := os.ReadDir(path)
	if err != nil {
		return false
	}

	return len(contents) == 0
}
