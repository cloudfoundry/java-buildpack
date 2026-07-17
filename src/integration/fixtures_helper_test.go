package integration_test

import (
	"archive/zip"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	javaTestAppsReleaseTag = "v1.0.0"
	javaTestAppsBaseURL = "https://github.com/cloudfoundry/java-test-applications/releases/download/" + javaTestAppsReleaseTag
	sb3JarName          = "java-main-application-boot3-1.0.0.jar"
	sb4JarName          = "java-main-application-1.0.0.jar"
)

// downloadJavaTestAppsJars downloads the pinned SB3 and SB4 fat jars.
// For Docker-mode tests, jars are extracted (exploded) into fixture directories
// to simulate what real CF staging does: CF treats the pushed artifact as a zip
// and extracts it before running the buildpack, so BOOT-INF/ and META-INF/
// appear as flat files on disk.
// For CF-mode tests, the raw jar is returned as-is — `cf push -p` handles
// zip extraction natively.
//
// Pre-exploding is the correct pattern for Docker-mode tests: switchblade's
// Docker mode archives the fixture directory as-is (TGZArchiver), while CF mode
// delegates to `cf push -p` which handles zip extraction natively.
// See https://github.com/cloudfoundry/switchblade/issues/134 for details.
//
// Returns (sb3FixturePath, sb4FixturePath, cleanup func, error).
func downloadJavaTestAppsJars(platform string) (string, string, func(), error) {
	dir, err := os.MkdirTemp("", "java-test-apps-*")
	if err != nil {
		return "", "", nil, fmt.Errorf("create temp dir: %w", err)
	}

	cleanup := func() { os.RemoveAll(dir) }

	type jarEntry struct {
		jarName string
		path    string // set after download/extract
	}
	entries := []jarEntry{
		{jarName: sb3JarName},
		{jarName: sb4JarName},
	}

	for i := range entries {
		jarPath := filepath.Join(dir, entries[i].jarName)
		if err := downloadFile(javaTestAppsBaseURL+"/"+entries[i].jarName, jarPath); err != nil {
			cleanup()
			return "", "", nil, fmt.Errorf("download %s: %w", entries[i].jarName, err)
		}

		if platform == "docker" {
			// Docker mode: explode jar into directory (simulates CF staging zip extraction).
			// Switchblade Docker archives the fixture dir as-is via TGZArchiver.
			explodedDir := filepath.Join(dir, fmt.Sprintf("exploded-%d", i))
			if err := extractZip(jarPath, explodedDir); err != nil {
				cleanup()
				return "", "", nil, fmt.Errorf("extract %s: %w", entries[i].jarName, err)
			}
			_ = os.Remove(jarPath)
			entries[i].path = explodedDir
		} else {
			// CF mode: return raw jar path — `cf push -p` handles zip extraction natively.
			entries[i].path = jarPath
		}
	}

	return entries[0].path, entries[1].path, cleanup, nil
}

// extractZip extracts a zip/jar file into destDir, replicating the flat-file
// layout that CF staging creates when it unpacks the pushed artifact.
func extractZip(src, destDir string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return fmt.Errorf("open zip: %w", err)
	}
	defer r.Close()

	for _, f := range r.File {
		target := filepath.Join(destDir, f.Name)

		// Guard against zip-slip
		if !strings.HasPrefix(filepath.Clean(target)+string(os.PathSeparator),
			filepath.Clean(destDir)+string(os.PathSeparator)) {
			return fmt.Errorf("zip entry %q escapes destination", f.Name)
		}

		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(target, 0755); err != nil {
				return err
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			return err
		}

		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, f.Mode())
		if err != nil {
			return err
		}

		rc, err := f.Open()
		if err != nil {
			out.Close()
			return err
		}

		_, copyErr := io.Copy(out, rc)
		rc.Close()
		out.Close()
		if copyErr != nil {
			return copyErr
		}
	}
	return nil
}

func downloadFile(url, dest string) error {
	client := &http.Client{Timeout: 2 * time.Minute}
	resp, err := client.Get(url) //nolint:noctx
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d for %s", resp.StatusCode, url)
	}

	f, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer f.Close()

	_, err = io.Copy(f, resp.Body)
	return err
}
