package integration_test

import (
	"archive/zip"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
)

// defaultJavaVersion is the JRE used by tests whose subject is not a specific Java version.
// Tests that exercise a particular Java version (or an app that cannot run on the newest JRE) pin their own.
const defaultJavaVersion = "25"

// requireJar returns the fixture path of a downloaded java-test-applications app, skipping the test
// when it was not downloaded (cached/offline mode).
func requireJar(t *testing.T, path string) string {
	t.Helper()
	if path == "" {
		t.Skip("java-test-applications app not available (cached mode)")
	}
	return path
}

// appWithFile returns a copy of the fixture app at src with an extra file at relPath in the app root.
// The fixture is either an exploded directory (Docker mode) or a jar file (CF mode).
func appWithFile(t *testing.T, src, relPath, content string) string {
	t.Helper()

	tmp, err := os.MkdirTemp("", "java-app-fixture-*")
	if err != nil {
		t.Fatalf("create temp dir: %v", err)
	}
	t.Cleanup(func() { os.RemoveAll(tmp) })

	info, err := os.Stat(src)
	if err != nil {
		t.Fatalf("stat %s: %v", src, err)
	}

	if info.IsDir() {
		dst := filepath.Join(tmp, filepath.Base(src))
		if err := copyDir(src, dst); err != nil {
			t.Fatalf("copy %s: %v", src, err)
		}
		target := filepath.Join(dst, relPath)
		if err := os.MkdirAll(filepath.Dir(target), 0755); err != nil {
			t.Fatalf("create dir for %s: %v", relPath, err)
		}
		if err := os.WriteFile(target, []byte(content), 0644); err != nil {
			t.Fatalf("write %s: %v", relPath, err)
		}
		return dst
	}

	dst := filepath.Join(tmp, filepath.Base(src))
	if err := rezipWithFile(src, dst, relPath, content); err != nil {
		t.Fatalf("add %s to %s: %v", relPath, src, err)
	}
	return dst
}

func copyDir(src, dst string) error {
	return filepath.WalkDir(src, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, path)
		if err != nil {
			return err
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0755)
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, info.Mode())
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	})
}

// rezipWithFile copies the zip at src to dst, adding one entry. Entries are copied raw, so Spring Boot's
// requirement that nested jars stay uncompressed is preserved.
func rezipWithFile(src, dst, relPath, content string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer r.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	w := zip.NewWriter(out)
	for _, f := range r.File {
		if err := w.Copy(f); err != nil {
			return err
		}
	}
	entry, err := w.Create(relPath)
	if err != nil {
		return err
	}
	if _, err := entry.Write([]byte(content)); err != nil {
		return err
	}
	return w.Close()
}
