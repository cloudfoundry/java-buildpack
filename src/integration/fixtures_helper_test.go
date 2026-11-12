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
	javaTestAppsVersion    = "1.0.1"
	javaTestAppsReleaseTag = "v" + javaTestAppsVersion
	javaTestAppsBaseURL    = "https://github.com/cloudfoundry/java-test-applications/releases/download/" + javaTestAppsReleaseTag
	sb3JarName             = "java-main-application-boot3-" + javaTestAppsVersion + ".jar"
	sb4JarName             = "java-main-application-" + javaTestAppsVersion + ".jar"

	executableWarName      = "executable-war-application-" + javaTestAppsVersion + ".war"
	executableWarBoot3Name = "executable-war-application-boot3-" + javaTestAppsVersion + ".war"
	mainClassWarName       = "main-class-war-application-" + javaTestAppsVersion + ".war"
)

// javaTestAppsURL returns the download URL of a release artifact. JAVA_TEST_APPS_BASE_URL lets a not-yet-released build of java-test-applications
// be served locally, e.g. JAVA_TEST_APPS_BASE_URL=http://localhost:8000.
func javaTestAppsURL(artifact string) string {
	base := javaTestAppsBaseURL
	if override := os.Getenv("JAVA_TEST_APPS_BASE_URL"); override != "" {
		base = strings.TrimSuffix(override, "/")
	}
	return base + "/" + artifact
}

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
	paths, cleanup, err := downloadJavaTestApps(platform, sb3JarName, sb4JarName)
	if err != nil {
		return "", "", nil, err
	}
	return paths[sb3JarName], paths[sb4JarName], cleanup, nil
}

// downloadJavaTestApps downloads the given release artifacts and returns a map from artifact name to the
// fixture path to deploy (see downloadJavaTestAppsJars for why Docker mode explodes the archive).
func downloadJavaTestApps(platform string, artifacts ...string) (map[string]string, func(), error) {
	dir, err := os.MkdirTemp("", "java-test-apps-*")
	if err != nil {
		return nil, nil, fmt.Errorf("create temp dir: %w", err)
	}
	cleanup := func() { os.RemoveAll(dir) }

	paths := make(map[string]string, len(artifacts))
	for _, artifact := range artifacts {
		path, err := fetchJavaTestApp(platform, dir, artifact)
		if err != nil {
			cleanup()
			return nil, nil, err
		}
		paths[artifact] = path
	}
	return paths, cleanup, nil
}

func fetchJavaTestApp(platform, dir, artifact string) (string, error) {
	archivePath := filepath.Join(dir, artifact)
	if err := downloadFile(javaTestAppsURL(artifact), archivePath); err != nil {
		return "", fmt.Errorf("download %s: %w", artifact, err)
	}

	if platform != "docker" {
		// CF mode: return the raw archive, `cf push -p` handles zip extraction natively.
		return archivePath, nil
	}

	// Docker mode: explode the archive into a directory (simulates CF staging zip extraction).
	// Switchblade Docker archives the fixture dir as-is via TGZArchiver.
	explodedDir := filepath.Join(dir, "exploded-"+artifact)
	if err := extractZip(archivePath, explodedDir); err != nil {
		return "", fmt.Errorf("extract %s: %w", artifact, err)
	}
	_ = os.Remove(archivePath)
	return explodedDir, nil
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
