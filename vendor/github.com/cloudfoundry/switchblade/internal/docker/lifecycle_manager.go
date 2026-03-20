package docker

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sync"

	"github.com/paketo-buildpacks/packit/v2/pexec"
	"github.com/paketo-buildpacks/packit/v2/vacation"
)

var goVersionRegexp = regexp.MustCompile(`go(\d+\.\d+)`)

//go:generate faux --interface Executable --output fakes/executable.go
type Executable interface {
	Execute(pexec.Execution) error
}

type LifecycleManager struct {
	golang   Executable
	archiver Archiver
	m        *sync.Mutex
}

func NewLifecycleManager(golang Executable, archiver Archiver) LifecycleManager {
	return LifecycleManager{
		golang:   golang,
		archiver: archiver,
		m:        &sync.Mutex{},
	}
}

func (b LifecycleManager) Build(sourceURI, workspace string) (string, error) {
	b.m.Lock()
	defer b.m.Unlock()

	req, err := http.NewRequest("GET", sourceURI, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	etag, err := os.ReadFile(filepath.Join(workspace, "etag"))
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("failed to read etag: %w", err)
	}

	if len(etag) > 0 {
		req.Header.Set("If-None-Match", string(etag))
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to complete request: %w", err)
	}
	defer resp.Body.Close()

	output := filepath.Join(workspace, "lifecycle.tar.gz")
	if resp.StatusCode == http.StatusNotModified {
		return output, nil
	}

	err = os.RemoveAll(workspace)
	if err != nil {
		return "", fmt.Errorf("failed to clear workspace: %w", err)
	}

	err = vacation.NewZipArchive(resp.Body).StripComponents(1).Decompress(filepath.Join(workspace, "repo"))
	if err != nil {
		return "", fmt.Errorf("failed to decompress lifecycle repo: %w", err)
	}

	env := append(os.Environ(), "GOOS=linux", "GOARCH=amd64")
	buffer := bytes.NewBuffer(nil)

	_, err = os.Stat(filepath.Join(workspace, "repo", "go.mod"))
	if errors.Is(err, os.ErrNotExist) {
		err = b.golang.Execute(pexec.Execution{
			Args:   []string{"mod", "init", "code.cloudfoundry.org/buildpackapplifecycle"},
			Env:    env,
			Dir:    filepath.Join(workspace, "repo"),
			Stdout: buffer,
			Stderr: buffer,
		})
		if err != nil {
			return "", fmt.Errorf("failed to initialize go module: %w\n\n%s", err, buffer)
		}
	} else if err != nil {
		return "", fmt.Errorf("failed to stat go.mod: %w", err)
	}

	versionBuffer := bytes.NewBuffer(nil)
	err = b.golang.Execute(pexec.Execution{
		Args:   []string{"version"},
		Env:    env,
		Dir:    filepath.Join(workspace, "repo"),
		Stdout: io.MultiWriter(versionBuffer, buffer),
		Stderr: buffer,
	})
	if err != nil {
		return "", fmt.Errorf("failed to identify go version: %w\n\n%s", err, buffer)
	}

	args := []string{"mod", "tidy"}
	matches := goVersionRegexp.FindStringSubmatch(versionBuffer.String())
	if len(matches) == 2 {
		args = append(args, "-compat", matches[1])
	}

	err = b.golang.Execute(pexec.Execution{
		Args:   args,
		Env:    env,
		Dir:    filepath.Join(workspace, "repo"),
		Stdout: buffer,
		Stderr: buffer,
	})
	if err != nil {
		return "", fmt.Errorf("failed to tidy go module: %w\n\n%s", err, buffer)
	}

	err = os.MkdirAll(filepath.Join(workspace, "output"), os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to create output directory: %w", err)
	}

	err = b.golang.Execute(pexec.Execution{
		Args:   []string{"build", "-o", filepath.Join(workspace, "output", "builder"), "./builder"},
		Env:    env,
		Dir:    filepath.Join(workspace, "repo"),
		Stdout: buffer,
		Stderr: buffer,
	})
	if err != nil {
		return "", fmt.Errorf("failed to build lifecycle builder: %w\n\n%s", err, buffer)
	}

	err = b.golang.Execute(pexec.Execution{
		Args:   []string{"build", "-o", filepath.Join(workspace, "output", "launcher"), "./launcher"},
		Env:    env,
		Dir:    filepath.Join(workspace, "repo"),
		Stdout: buffer,
		Stderr: buffer,
	})
	if err != nil {
		return "", fmt.Errorf("failed to build lifecycle launcher: %w\n\n%s", err, buffer)
	}

	err = b.archiver.WithPrefix("/tmp/lifecycle").Compress(filepath.Join(workspace, "output"), output)
	if err != nil {
		return "", fmt.Errorf("failed to archive lifecycle: %w", err)
	}

	err = os.WriteFile(filepath.Join(workspace, "etag"), []byte(resp.Header.Get("ETag")), 0600)
	if err != nil {
		return "", fmt.Errorf("failed to write lifecycle etag file: %w", err)
	}

	return output, nil
}
