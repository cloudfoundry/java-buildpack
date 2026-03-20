package libbuildpack

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	backoff "github.com/cenkalti/backoff/v4"
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

func MoveDirectory(srcDir, destDir string) error {
	destExists, _ := FileExists(destDir)
	if !destExists {
		return os.Rename(srcDir, destDir)
	}

	files, err := ioutil.ReadDir(srcDir)
	if err != nil {
		return err
	}
	for _, f := range files {
		src := filepath.Join(srcDir, f.Name())
		dest := filepath.Join(destDir, f.Name())

		if exists, err := FileExists(dest); err != nil {
			return err
		} else if !exists {
			if m := f.Mode(); m&os.ModeSymlink != 0 {
				if err = moveSymlinks(src, dest); err != nil {
					return err
				}
			}
			if err = os.Rename(src, dest); err != nil {
				return err
			}
		} else {
			if f.IsDir() {
				if err = MoveDirectory(src, dest); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

// CopyDirectory copies srcDir to destDir
func CopyDirectory(srcDir, destDir string) error {
	destExists, _ := FileExists(destDir)
	if !destExists {
		return errors.New("destination dir must exist")
	}

	files, err := ioutil.ReadDir(srcDir)
	if err != nil {
		return err
	}

	for _, f := range files {
		src := filepath.Join(srcDir, f.Name())
		dest := filepath.Join(destDir, f.Name())

		if m := f.Mode(); m&os.ModeSymlink != 0 {
			if err = moveSymlinks(src, dest); err != nil {
				return err
			}
		} else if f.IsDir() {
			err = os.MkdirAll(dest, f.Mode())
			if err != nil {
				return err
			}
			if err := CopyDirectory(src, dest); err != nil {
				return err
			}
		} else {
			rc, err := os.Open(src)
			if err != nil {
				return err
			}

			err = writeToFile(rc, dest, f.Mode())
			if err != nil {
				rc.Close()
				return err
			}
			rc.Close()
		}
	}

	return nil
}

func moveSymlinks(src, dest string) error {
	target, err := os.Readlink(src)
	if err != nil {
		return fmt.Errorf("Error while reading symlink '%s': %v", src, err)
	}
	if err := os.Symlink(target, dest); err != nil {
		return fmt.Errorf("Error while creating '%s' as symlink to '%s': %v", dest, target, err)
	}
	return nil
}

// ExtractZip extracts zipfile to destDir
func ExtractZip(zipfile, destDir string) error {
	r, err := zip.OpenReader(zipfile)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		path := filepath.Join(destDir, filepath.Clean(f.Name))

		rc, err := f.Open()
		if err != nil {
			return err
		}

		if f.FileInfo().IsDir() {
			err = os.MkdirAll(path, f.Mode())
		} else {
			err = writeToFile(rc, path, f.Mode())
		}

		rc.Close()
		if err != nil {
			return err
		}
	}

	return nil
}

// ExtractZipWithStrip extracts zipfile to destDir, optionally stripping N leading path components
// stripComponents works like tar's --strip-components flag:
//
//	0 = extract as-is (default)
//	1 = remove top-level directory
//	2 = remove two levels, etc.
func ExtractZipWithStrip(zipfile, destDir string, stripComponents int) error {
	r, err := zip.OpenReader(zipfile)
	if err != nil {
		return err
	}
	defer r.Close()

	for _, f := range r.File {
		// Strip leading path components
		name := filepath.Clean(f.Name)
		if stripComponents > 0 {
			parts := strings.Split(name, string(filepath.Separator))
			if len(parts) <= stripComponents {
				// Skip files/dirs that would be completely stripped away
				continue
			}
			name = filepath.Join(parts[stripComponents:]...)
		}

		path := filepath.Join(destDir, name)

		rc, err := f.Open()
		if err != nil {
			return err
		}

		if f.FileInfo().IsDir() {
			err = os.MkdirAll(path, f.Mode())
		} else {
			err = writeToFile(rc, path, f.Mode())
		}

		rc.Close()
		if err != nil {
			return err
		}
	}

	return nil
}

func ExtractTarXz(tarfile, destDir string) error {
	file, err := os.Open(tarfile)
	if err != nil {
		return err
	}
	defer file.Close()
	xz := xzReader(file)
	defer xz.Close()
	return extractTar(xz, destDir)
}

// ExtractTarXzWithStrip extracts tar.xz to destDir, optionally stripping N leading path components
// stripComponents works like tar's --strip-components flag:
//
//	0 = extract as-is (default)
//	1 = remove top-level directory
//	2 = remove two levels, etc.
func ExtractTarXzWithStrip(tarfile, destDir string, stripComponents int) error {
	file, err := os.Open(tarfile)
	if err != nil {
		return err
	}
	defer file.Close()
	xz := xzReader(file)
	defer xz.Close()
	return extractTarWithStrip(xz, destDir, stripComponents)
}

func xzReader(r io.Reader) io.ReadCloser {
	rpipe, wpipe := io.Pipe()

	cmd := exec.Command("xz", "--decompress", "--stdout")
	cmd.Stdin = r
	cmd.Stdout = wpipe

	go func() {
		err := cmd.Run()
		wpipe.CloseWithError(err)
	}()

	return rpipe
}

// Gets the buildpack directory
func GetBuildpackDir() (string, error) {
	var err error

	bpDir := os.Getenv("BUILDPACK_DIR")

	if bpDir == "" {
		bpDir, err = filepath.Abs(filepath.Join(filepath.Dir(os.Args[0]), ".."))

		if err != nil {
			return "", err
		}
	}

	return bpDir, nil
}

// ExtractTarGz extracts tar.gz to destDir
func ExtractTarGz(tarfile, destDir string) error {
	file, err := os.Open(tarfile)
	if err != nil {
		return err
	}
	defer file.Close()
	gz, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gz.Close()
	return extractTar(gz, destDir)
}

// ExtractTarGzWithStrip extracts tar.gz to destDir, optionally stripping N leading path components
// stripComponents works like tar's --strip-components flag:
//
//	0 = extract as-is (default)
//	1 = remove top-level directory
//	2 = remove two levels, etc.
func ExtractTarGzWithStrip(tarfile, destDir string, stripComponents int) error {
	file, err := os.Open(tarfile)
	if err != nil {
		return err
	}
	defer file.Close()
	gz, err := gzip.NewReader(file)
	if err != nil {
		return err
	}
	defer gz.Close()
	return extractTarWithStrip(gz, destDir, stripComponents)
}

// CopyFile copies source file to destFile, creating all intermediate directories in destFile
func CopyFile(source, destFile string) error {
	fh, err := os.Open(source)
	if err != nil {
		return err
	}

	fileInfo, err := fh.Stat()
	if err != nil {
		return err
	}

	defer fh.Close()

	return writeToFile(fh, destFile, fileInfo.Mode())
}

func FileExists(file string) (bool, error) {
	_, err := os.Stat(file)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}

		return false, err
	}

	return true, nil
}

func RandString(n int) string {
	letterRunes := []rune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
	b := make([]rune, n)
	for i := range b {
		b[i] = letterRunes[rand.Intn(len(letterRunes))]
	}
	return string(b)
}

func extractTar(src io.Reader, destDir string) error {
	tr := tar.NewReader(src)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		path := filepath.Join(destDir, cleanPath(hdr.Name))

		fi := hdr.FileInfo()
		if fi.IsDir() {
			if err := os.MkdirAll(path, hdr.FileInfo().Mode()); err != nil {
				return err
			}
		} else if hdr.Typeflag == tar.TypeSymlink {
			if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
				return err
			}

			if filepath.IsAbs(hdr.Linkname) {
				return fmt.Errorf("cannot link to an absolute path when extracting archives")
			}

			fullLink, err := filepath.Abs(filepath.Join(filepath.Dir(path), hdr.Linkname))
			if err != nil {
				return err
			}

			fullDest, err := filepath.Abs(destDir)
			if err != nil {
				return err
			}

			// check that the relative link does not escape the destination dir
			if !strings.HasPrefix(fullLink, fullDest) {
				return fmt.Errorf("cannot link outside of the destination diretory when extracting archives")
			}

			if err = os.Symlink(hdr.Linkname, path); err != nil {
				return err
			}
		} else if hdr.Typeflag == tar.TypeLink {
			originalPath := filepath.Join(destDir, cleanPath(hdr.Linkname))
			file, err := os.Open(originalPath)
			if err != nil {
				return err
			}

			if err := writeToFile(file, path, hdr.FileInfo().Mode()); err != nil {
				return err
			}

		} else {
			if err := writeToFile(tr, path, hdr.FileInfo().Mode()); err != nil {
				return err
			}
		}
	}
	return nil
}

func extractTarWithStrip(src io.Reader, destDir string, stripComponents int) error {
	tr := tar.NewReader(src)

	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}

		// Strip leading path components
		name := cleanPath(hdr.Name)
		if stripComponents > 0 {
			parts := strings.Split(name, string(filepath.Separator))
			if len(parts) <= stripComponents {
				// Skip files/dirs that would be completely stripped away
				continue
			}
			name = filepath.Join(parts[stripComponents:]...)
		}

		path := filepath.Join(destDir, name)

		fi := hdr.FileInfo()
		if fi.IsDir() {
			if err := os.MkdirAll(path, hdr.FileInfo().Mode()); err != nil {
				return err
			}
		} else if hdr.Typeflag == tar.TypeSymlink {
			if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
				return err
			}

			if filepath.IsAbs(hdr.Linkname) {
				return fmt.Errorf("cannot link to an absolute path when extracting archives")
			}

			fullLink, err := filepath.Abs(filepath.Join(filepath.Dir(path), hdr.Linkname))
			if err != nil {
				return err
			}

			fullDest, err := filepath.Abs(destDir)
			if err != nil {
				return err
			}

			// check that the relative link does not escape the destination dir
			if !strings.HasPrefix(fullLink, fullDest) {
				return fmt.Errorf("cannot link outside of the destination diretory when extracting archives")
			}

			if err = os.Symlink(hdr.Linkname, path); err != nil {
				return err
			}
		} else if hdr.Typeflag == tar.TypeLink {
			// For hard links, also strip the link target path
			linkname := cleanPath(hdr.Linkname)
			if stripComponents > 0 {
				parts := strings.Split(linkname, string(filepath.Separator))
				if len(parts) <= stripComponents {
					// Skip if link target would be stripped away
					continue
				}
				linkname = filepath.Join(parts[stripComponents:]...)
			}
			originalPath := filepath.Join(destDir, linkname)
			file, err := os.Open(originalPath)
			if err != nil {
				return err
			}

			if err := writeToFile(file, path, hdr.FileInfo().Mode()); err != nil {
				return err
			}

		} else {
			if err := writeToFile(tr, path, hdr.FileInfo().Mode()); err != nil {
				return err
			}
		}
	}
	return nil
}

func filterURI(rawURL string) (string, error) {
	unsafeURL, err := url.Parse(rawURL)

	if err != nil {
		return "", err
	}

	var safeURL string

	if unsafeURL.User == nil {
		safeURL = rawURL
		return safeURL, nil
	}

	redactedUserInfo := url.UserPassword("-redacted-", "-redacted-")

	unsafeURL.User = redactedUserInfo
	safeURL = unsafeURL.String()

	return safeURL, nil
}

func CheckSha256(filePath, expectedSha256 string) error {
	content, err := ioutil.ReadFile(filePath)
	if err != nil {
		return err
	}

	sum := sha256.Sum256(content)

	actualSha256 := hex.EncodeToString(sum[:])

	if actualSha256 != expectedSha256 {
		return fmt.Errorf("dependency sha256 mismatch: expected sha256 %s, actual sha256 %s", expectedSha256, actualSha256)
	}
	return nil
}

func downloadFile(url string, destFile string, retryTimeLimit time.Duration, retryTimeInitialInterval time.Duration, logger *Logger) error {
	bo := backoff.NewExponentialBackOff()
	bo.MaxElapsedTime = retryTimeLimit
	bo.InitialInterval = retryTimeInitialInterval

	var resp *http.Response
	var err error

	operation := func() error {
		resp, err = http.Get(url)

		if err != nil {
			return err
		}
		defer resp.Body.Close()

		if resp.StatusCode >= 400 {
			return fmt.Errorf("%s", resp.Status)
		}
		return writeToFile(resp.Body, destFile, 0666)
	}

	notify := func(err error, duration time.Duration) {
		logger.Info("error: %v, retrying in %v...", err, duration)
	}

	err = backoff.RetryNotify(operation, bo, notify)

	if err != nil {
		return fmt.Errorf("could not download: %s", err)
	}

	return nil
}

func writeToFile(source io.Reader, destFile string, mode os.FileMode) error {
	err := os.MkdirAll(filepath.Dir(destFile), 0755)
	if err != nil {
		return err
	}

	fh, err := os.OpenFile(destFile, os.O_RDWR|os.O_CREATE|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer fh.Close()

	_, err = io.Copy(fh, source)
	if err != nil {
		return err
	}

	return nil
}

func cleanPath(path string) string {
	if path == "" {
		return ""
	}

	path = filepath.Clean(path)
	if !filepath.IsAbs(path) {
		path = filepath.Clean(string(os.PathSeparator) + path)
		path, _ = filepath.Rel(string(os.PathSeparator), path)
	}

	return filepath.Clean(path)
}
