package docker

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/image"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/errdefs"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
)

const (
	BuildpackAppLifecycleRepoURL = "https://github.com/cloudfoundry/buildpackapplifecycle/archive/refs/heads/main.zip"
	BridgeNetworkName            = "bridge"
)

type SetupPhase interface {
	Run(ctx context.Context, logs io.Writer, name, path string) (containerID string, err error)
	WithBuildpacks(buildpacks ...string) SetupPhase
	WithStack(stack string) SetupPhase
	WithEnv(env map[string]string) SetupPhase
	WithoutInternetAccess() SetupPhase
	WithServices(services map[string]map[string]interface{}) SetupPhase
}

//go:generate faux --interface SetupClient --output fakes/setup_client.go
type SetupClient interface {
	ImagePull(ctx context.Context, ref string, options image.PullOptions) (io.ReadCloser, error)
	ContainerCreate(ctx context.Context, config *container.Config, hostConfig *container.HostConfig, networkingConfig *network.NetworkingConfig, platform *specs.Platform, containerName string) (container.CreateResponse, error)
	CopyToContainer(ctx context.Context, containerID, dstPath string, content io.Reader, options container.CopyToContainerOptions) error
	ContainerInspect(ctx context.Context, containerID string) (types.ContainerJSON, error)
	ContainerRemove(ctx context.Context, containerID string, options container.RemoveOptions) error
}

//go:generate faux --interface LifecycleBuilder --output fakes/lifecycle_builder.go
type LifecycleBuilder interface {
	Build(sourceURI, workspace string) (path string, err error)
}

//go:generate faux --interface BuildpacksBuilder --output fakes/buildpacks_builder.go
type BuildpacksBuilder interface {
	Order() (order string, skipDetect bool, err error)
	Build(workspace, name string) (path string, err error)
	WithBuildpacks(buildpacks ...string) BuildpacksBuilder
}

//go:generate faux --interface Archiver --output fakes/archiver.go
type Archiver interface {
	WithPrefix(prefix string) Archiver
	Compress(input, output string) error
}

//go:generate faux --interface SetupNetworkManager --output fakes/setup_network_manager.go
type SetupNetworkManager interface {
	Create(ctx context.Context, name, driver string, internal bool) error
	Connect(ctx context.Context, containerID, name string) error
}

type Setup struct {
	client             SetupClient
	lifecycle          LifecycleBuilder
	archiver           Archiver
	buildpacks         BuildpacksBuilder
	stack              string
	networks           SetupNetworkManager
	workspace          string
	env                map[string]string
	disconnectInternet bool
	services           map[string]map[string]interface{}
}

func NewSetup(client SetupClient, lifecycle LifecycleBuilder, buildpacks BuildpacksBuilder, archiver Archiver, networks SetupNetworkManager, workspace, stack string) Setup {
	return Setup{
		client:     client,
		lifecycle:  lifecycle,
		stack:      stack,
		buildpacks: buildpacks,
		archiver:   archiver,
		networks:   networks,
		workspace:  workspace,
	}
}

func (s Setup) Run(ctx context.Context, logs io.Writer, name, path string) (string, error) {
	lifecycle, err := s.lifecycle.Build(BuildpackAppLifecycleRepoURL, filepath.Join(s.workspace, "lifecycle"))
	if err != nil {
		return "", fmt.Errorf("failed to build lifecycle: %w", err)
	}

	buildpacks, err := s.buildpacks.Build(filepath.Join(s.workspace, "buildpacks"), name)
	if err != nil {
		return "", fmt.Errorf("failed to build buildpacks: %w", err)
	}

	source := filepath.Join(s.workspace, "source", fmt.Sprintf("%s.tar.gz", name))
	err = s.archiver.WithPrefix("/tmp/app").Compress(path, source)
	if err != nil {
		return "", fmt.Errorf("failed to archive source code: %w", err)
	}

	pullLogs, err := s.client.ImagePull(ctx, fmt.Sprintf("cloudfoundry/%s:latest", s.stack), image.PullOptions{})
	if err != nil {
		return "", fmt.Errorf("failed to pull base image: %w", err)
	}
	defer pullLogs.Close()

	_, err = io.Copy(logs, pullLogs)
	if err != nil {
		return "", fmt.Errorf("failed to copy image pull logs: %w", err)
	}

	env := []string{fmt.Sprintf("CF_STACK=%s", s.stack)}
	for key, value := range s.env {
		env = append(env, fmt.Sprintf("%s=%s", key, value))
	}

	var serviceKeys []string
	for key := range s.services {
		serviceKeys = append(serviceKeys, key)
	}
	sort.Strings(serviceKeys)

	var services []map[string]interface{}
	for _, key := range serviceKeys {
		services = append(services, map[string]interface{}{
			"name":        fmt.Sprintf("%s-%s", name, key),
			"credentials": s.services[key],
		})
	}

	if len(services) > 0 {
		content, err := json.Marshal(map[string]interface{}{
			"user-provided": services,
		})
		if err != nil {
			return "", fmt.Errorf("failed to marshal services json: %w", err)
		}

		env = append(env, fmt.Sprintf("VCAP_SERVICES=%s", content))
	} else {
		env = append(env, "VCAP_SERVICES={}")
	}

	order, skipDetect, err := s.buildpacks.Order()
	if err != nil {
		return "", fmt.Errorf("failed to determine buildpack ordering: %w", err)
	}

	ctnr, err := s.client.ContainerInspect(ctx, name)
	if err != nil && !errdefs.IsNotFound(err) {
		return "", fmt.Errorf("failed to inspect staging container: %w", err)
	}
	if err == nil {
		err = s.client.ContainerRemove(ctx, ctnr.ID, container.RemoveOptions{Force: true})
		if err != nil {
			return "", fmt.Errorf("failed to remove conflicting container: %w", err)
		}
	}

	containerConfig := container.Config{
		Image: fmt.Sprintf("cloudfoundry/%s:latest", s.stack),
		Cmd: []string{
			"/tmp/lifecycle/builder",
			"--buildArtifactsCacheDir=/tmp/cache",
			"--buildDir=/tmp/app",
			fmt.Sprintf("--buildpackOrder=%s", order),
			"--buildpacksDir=/tmp/buildpacks",
			"--outputBuildArtifactsCache=/tmp/output-cache",
			"--outputDroplet=/tmp/droplet",
			"--outputMetadata=/tmp/result.json",
			fmt.Sprintf("--skipDetect=%t", skipDetect),
		},
		User:       "vcap",
		Env:        env,
		WorkingDir: "/home/vcap",
	}

	hostConfig := container.HostConfig{
		NetworkMode: container.NetworkMode(InternalNetworkName),
	}

	resp, err := s.client.ContainerCreate(ctx, &containerConfig, &hostConfig, nil, nil, name)
	if err != nil {
		return "", fmt.Errorf("failed to create staging container: %w", err)
	}

	if !s.disconnectInternet {
		err = s.networks.Connect(ctx, resp.ID, BridgeNetworkName)
		if err != nil {
			return "", fmt.Errorf("failed to connect container to network: %w", err)
		}
	}

	tarballs := []string{lifecycle, buildpacks, source}

	buildCachePath := filepath.Join(s.workspace, "build-cache", fmt.Sprintf("%s.tar.gz", name))
	_, err = os.Stat(buildCachePath)
	if err == nil {
		tarballs = append(tarballs, buildCachePath)
	}

	for _, tarballPath := range tarballs {
		tarball, err := os.Open(tarballPath)
		if err != nil {
			return "", fmt.Errorf("failed to open tarball: %w", err)
		}

		err = s.client.CopyToContainer(ctx, resp.ID, "/", tarball, container.CopyToContainerOptions{})
		if err != nil {
			return "", fmt.Errorf("failed to copy tarball to container: %w", err)
		}

		err = tarball.Close()
		if err != nil && !errors.Is(err, os.ErrClosed) {
			return "", fmt.Errorf("failed to close tarball: %w", err)
		}
	}

	return resp.ID, nil
}

func (s Setup) WithBuildpacks(buildpacks ...string) SetupPhase {
	s.buildpacks = s.buildpacks.WithBuildpacks(buildpacks...)
	return s
}

func (s Setup) WithStack(stack string) SetupPhase {
	s.stack = stack
	return s
}

func (s Setup) WithEnv(env map[string]string) SetupPhase {
	s.env = env
	return s
}

func (s Setup) WithoutInternetAccess() SetupPhase {
	s.disconnectInternet = true
	return s
}

func (s Setup) WithServices(services map[string]map[string]interface{}) SetupPhase {
	s.services = services
	return s
}
