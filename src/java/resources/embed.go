package resources

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

// EmbeddedResources contains all resource files embedded at compile time
// This includes Tomcat configuration files and other framework resources
//
//go:embed files/**/*
var EmbeddedResources embed.FS

// GetResource reads a single embedded resource file
// path is relative to files/ directory (e.g., "tomcat/conf/server.xml")
func GetResource(path string) ([]byte, error) {
	fullPath := filepath.Join("files", path)
	data, err := EmbeddedResources.ReadFile(fullPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read embedded resource %s: %w", path, err)
	}
	return data, nil
}

// ExtractToDir extracts all embedded resources to the target directory
// Preserves directory structure relative to files/
func ExtractToDir(targetDir string) error {
	return fs.WalkDir(EmbeddedResources, "files", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Calculate relative path (remove "files/" prefix)
		relPath, err := filepath.Rel("files", path)
		if err != nil {
			return fmt.Errorf("failed to calculate relative path: %w", err)
		}

		targetPath := filepath.Join(targetDir, relPath)

		if d.IsDir() {
			return os.MkdirAll(targetPath, 0755)
		}

		data, err := EmbeddedResources.ReadFile(path)
		if err != nil {
			return fmt.Errorf("failed to read %s: %w", path, err)
		}

		return os.WriteFile(targetPath, data, 0644)
	})
}

// ListResources returns all available resource file paths
// Paths are relative to files/ directory
func ListResources() ([]string, error) {
	var paths []string
	err := fs.WalkDir(EmbeddedResources, "files", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			relPath, err := filepath.Rel("files", path)
			if err != nil {
				return err
			}
			paths = append(paths, relPath)
		}
		return nil
	})
	return paths, err
}

// Exists checks if a resource file exists in embedded resources
func Exists(path string) bool {
	fullPath := filepath.Join("files", path)
	_, err := fs.Stat(EmbeddedResources, fullPath)
	return err == nil
}
