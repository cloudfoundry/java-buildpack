package switchblade

import (
	"context"
	"fmt"
	"io"

	"github.com/cloudfoundry/switchblade/internal/cloudfoundry"
	"github.com/docker/docker/api/types/container"
)

//go:generate faux --interface LogsClient --output fakes/logs_client.go
type LogsClient interface {
	ContainerLogs(ctx context.Context, container string, options container.LogsOptions) (io.ReadCloser, error)
}

type Deployment struct {
	Name        string
	ExternalURL string
	InternalURL string

	// Internal fields for log retrieval
	platform  string
	workspace string
	cfCLI     cloudfoundry.Executable
	dockerCLI LogsClient
}

// RuntimeLogs retrieves recent logs from the running application.
// These are logs generated after the application has started (post-staging).
// This method abstracts platform-specific log retrieval for both
// CloudFoundry and Docker platforms.
//
// Use this for testing:
//   - Application startup messages
//   - Service connections
//   - Module/extension loading
//   - Runtime configuration
//
// For build-time logs (staging, buildpack detection), use the logs
// returned from platform.Deploy.Execute() instead.
func (d Deployment) RuntimeLogs() (string, error) {
	switch d.platform {
	case CloudFoundry:
		return d.logsCloudFoundry()
	case Docker:
		return d.logsDocker()
	default:
		return "", fmt.Errorf("unknown platform type: %q", d.platform)
	}
}

func (d Deployment) logsCloudFoundry() (string, error) {
	return cloudfoundry.FetchRecentLogs(d.cfCLI, d.workspace, d.Name)
}

func (d Deployment) logsDocker() (string, error) {
	ctx := context.Background()

	options := container.LogsOptions{
		ShowStdout: true,
		ShowStderr: true,
	}

	reader, err := d.dockerCLI.ContainerLogs(ctx, d.Name, options)
	if err != nil {
		return "", fmt.Errorf("failed to retrieve container logs: %w", err)
	}
	defer reader.Close()

	logs, err := io.ReadAll(reader)
	if err != nil {
		return "", fmt.Errorf("failed to read logs: %w", err)
	}

	return string(logs), nil
}
