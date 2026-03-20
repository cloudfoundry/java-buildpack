package vacation

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// This function checks to see that the given path is within the destination
// directory
func checkExtractPath(tarFilePath string, destination string) error {
	osPath := filepath.FromSlash(tarFilePath)
	destpath := filepath.Join(destination, osPath)
	if !strings.HasPrefix(destpath, filepath.Clean(destination)+string(os.PathSeparator)) {
		return fmt.Errorf("illegal file path %q: the file path does not occur within the destination directory", tarFilePath)
	}
	return nil
}

// Generates the full path for a symlink from the linkname and the symlink path
func linknameFullPath(path, linkname string) string {
	return filepath.Clean(filepath.Join(filepath.Dir(path), linkname))
}
