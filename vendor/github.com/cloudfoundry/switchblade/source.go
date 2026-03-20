package switchblade

import (
	"crypto/rand"
	"os"
	"path/filepath"

	"github.com/paketo-buildpacks/packit/v2/fs"
)

func Source(path string) (string, error) {
	destination, err := os.MkdirTemp("", "source")
	if err != nil {
		return "", err
	}

	err = fs.Copy(path, destination)
	if err != nil {
		return "", err
	}

	content := make([]byte, 32)
	_, err = rand.Read(content)
	if err != nil {
		return "", err
	}

	err = os.WriteFile(filepath.Join(destination, ".switchblade-key"), content, 0600)
	if err != nil {
		return "", err
	}

	return destination, nil
}
