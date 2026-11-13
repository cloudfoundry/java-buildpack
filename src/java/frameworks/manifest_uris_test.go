package frameworks_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"go.yaml.in/yaml/v3"
)

// A dependency URI must point to one fixed artifact. A floating URI such as
// .../latest/... changes content without changing the URI, so the pinned sha256
// breaks whenever the vendor republishes, and the packager keeps reusing a stale
// download that is cached under the URI.
func TestManifestDependencyURIsAreNotFloating(t *testing.T) {
	data, err := os.ReadFile(filepath.Join("..", "..", "..", "manifest.yml"))
	if err != nil {
		t.Fatalf("read manifest.yml: %v", err)
	}

	var manifest struct {
		Dependencies []struct {
			Name    string `yaml:"name"`
			Version string `yaml:"version"`
			URI     string `yaml:"uri"`
		} `yaml:"dependencies"`
	}
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		t.Fatalf("parse manifest.yml: %v", err)
	}
	if len(manifest.Dependencies) == 0 {
		t.Fatal("no dependencies found in manifest.yml")
	}

	for _, dependency := range manifest.Dependencies {
		if strings.Contains(dependency.URI, "/latest/") {
			t.Errorf("%s %s has a floating uri, use the versioned artifact instead: %s",
				dependency.Name, dependency.Version, dependency.URI)
		}
	}
}
