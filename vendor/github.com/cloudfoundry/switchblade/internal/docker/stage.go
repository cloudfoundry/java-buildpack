package docker

import (
	"archive/tar"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/pkg/stdcopy"
)

type StagePhase interface {
	Run(ctx context.Context, logs io.Writer, containerID, name string) (command string, err error)
}

//go:generate faux --interface StageClient --output fakes/stage_client.go
type StageClient interface {
	ContainerStart(ctx context.Context, containerID string, options container.StartOptions) error
	ContainerWait(ctx context.Context, containerID string, condition container.WaitCondition) (<-chan container.WaitResponse, <-chan error)
	ContainerLogs(ctx context.Context, container string, options container.LogsOptions) (io.ReadCloser, error)
	CopyFromContainer(ctx context.Context, containerID, srcPath string) (io.ReadCloser, container.PathStat, error)
	ContainerRemove(ctx context.Context, containerID string, options container.RemoveOptions) error
}

type Stage struct {
	client    StageClient
	archiver  Archiver
	workspace string
}

func NewStage(client StageClient, archiver Archiver, workspace string) Stage {
	return Stage{
		client:    client,
		archiver:  archiver,
		workspace: workspace,
	}
}

func (s Stage) Run(ctx context.Context, logs io.Writer, containerID, name string) (string, error) {
	err := s.client.ContainerStart(ctx, containerID, container.StartOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to start container: %w", err)
	}

	var status container.WaitResponse
	onExit, onErr := s.client.ContainerWait(ctx, containerID, container.WaitConditionNotRunning)
	select {
	case err := <-onErr:
		if err != nil {
			return "", fmt.Errorf("failed to wait on container: %w", err)
		}
	case status = <-onExit:
	}

	containerLogs, err := s.client.ContainerLogs(ctx, containerID, container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
	})
	if err != nil {
		return "", fmt.Errorf("failed to fetch container logs: %w", err)
	}
	defer containerLogs.Close()

	_, err = stdcopy.StdCopy(logs, logs, containerLogs)
	if err != nil {
		return "", fmt.Errorf("failed to copy container logs: %w", err)
	}

	if status.StatusCode != 0 {
		err = s.client.ContainerRemove(ctx, containerID, container.RemoveOptions{Force: true})
		if err != nil {
			return "", fmt.Errorf("failed to remove container: %w", err)
		}

		return "", fmt.Errorf("App staging failed: container exited with non-zero status code (%d)", status.StatusCode)
	}

	droplet, _, err := s.client.CopyFromContainer(ctx, containerID, "/tmp/droplet")
	if err != nil {
		return "", fmt.Errorf("failed to copy droplet from container: %w", err)
	}
	defer droplet.Close()

	err = os.MkdirAll(filepath.Join(s.workspace, "droplets"), os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to create droplets directory: %w", err)
	}

	dropletFile, err := os.Create(filepath.Join(s.workspace, "droplets", fmt.Sprintf("%s.tar.gz", name)))
	if err != nil {
		return "", fmt.Errorf("failed to create droplet tarball: %w", err)
	}
	defer dropletFile.Close()

	tr := tar.NewReader(droplet)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("failed to retrieve droplet from tarball: %w", err)
		}

		if hdr.Name == "droplet" {
			_, err = io.CopyN(dropletFile, tr, hdr.Size)
			if err != nil {
				return "", fmt.Errorf("failed to copy droplet from tarball: %w", err)
			}
		}
	}

	buildCache, _, err := s.client.CopyFromContainer(ctx, containerID, "/tmp/output-cache")
	if err != nil {
		return "", fmt.Errorf("failed to copy build cache from container: %w", err)
	}
	defer buildCache.Close()

	err = os.MkdirAll(filepath.Join(s.workspace, "build-cache"), os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to create build-cache directory: %w", err)
	}

	tr = tar.NewReader(buildCache)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("failed to retrieve build cache from tarball: %w", err)
		}

		if hdr.Name == "output-cache" {
			cachePath := filepath.Join(s.workspace, "build-cache", name)
			outputFile, err := os.Create(cachePath)
			if err != nil {
				return "", fmt.Errorf("failed to create build-cache path: %w", err)
			}

			_, err = io.CopyN(outputFile, tr, hdr.Size)
			if err != nil {
				return "", fmt.Errorf("failed to copy build cache: %w", err)
			}
			defer os.RemoveAll(cachePath)

			err = s.archiver.WithPrefix("/tmp/cache").Compress(cachePath, filepath.Join(s.workspace, "build-cache", fmt.Sprintf("%s.tar.gz", name)))
			if err != nil {
				return "", fmt.Errorf("failed to recompress build cache: %w", err)
			}
		}
	}

	result, _, err := s.client.CopyFromContainer(ctx, containerID, "/tmp/result.json")
	if err != nil {
		return "", fmt.Errorf("failed to copy result.json from container: %w", err)
	}
	defer result.Close()

	buffer := bytes.NewBuffer(nil)

	tr = tar.NewReader(result)
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return "", fmt.Errorf("failed to retrieve result.json from tarball: %w", err)
		}

		if hdr.Name == "result.json" {
			_, err = io.CopyN(buffer, tr, hdr.Size)
			if err != nil {
				return "", fmt.Errorf("failed to copy result.json from tarball: %w", err)
			}
		}
	}

	var resultContent struct {
		Processes []struct {
			Type    string `json:"type"`
			Command string `json:"command"`
		} `json:"processes"`
	}
	err = json.NewDecoder(buffer).Decode(&resultContent)
	if err != nil {
		return "", fmt.Errorf("failed to parse result.json: %w", err)
	}

	var command string
	for _, process := range resultContent.Processes {
		if process.Type == "web" {
			command = process.Command
		}
	}

	err = s.client.ContainerRemove(ctx, containerID, container.RemoveOptions{Force: true})
	if err != nil {
		return "", fmt.Errorf("failed to remove container: %w", err)
	}

	return command, nil
}
