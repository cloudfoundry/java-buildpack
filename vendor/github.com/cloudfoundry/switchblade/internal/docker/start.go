package docker

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/api/types/network"
	"github.com/docker/go-connections/nat"
	specs "github.com/opencontainers/image-spec/specs-go/v1"
)

type StartPhase interface {
	Run(ctx context.Context, logs io.Writer, name, command string) (externalURL, internalURL string, err error)
	WithStack(stack string) StartPhase
	WithEnv(env map[string]string) StartPhase
	WithServices(services map[string]map[string]interface{}) StartPhase
	WithStartCommand(command string) StartPhase
}

//go:generate faux --interface StartClient --output fakes/start_client.go
type StartClient interface {
	ContainerCreate(ctx context.Context, config *container.Config, hostConfig *container.HostConfig, networkingConfig *network.NetworkingConfig, platform *specs.Platform, containerName string) (container.CreateResponse, error)
	CopyToContainer(ctx context.Context, containerID, dstPath string, content io.Reader, options container.CopyToContainerOptions) error
	ContainerStart(ctx context.Context, containerID string, options container.StartOptions) error
	ContainerInspect(ctx context.Context, containerID string) (types.ContainerJSON, error)
}

//go:generate faux --interface StartNetworkManager --output fakes/start_network_manager.go
type StartNetworkManager interface {
	Connect(ctx context.Context, containerID, name string) error
}

type Start struct {
	client       StartClient
	networks     StartNetworkManager
	workspace    string
	stack        string
	env          map[string]string
	services     map[string]map[string]interface{}
	startCommand string
}

func NewStart(client StartClient, networks StartNetworkManager, workspace, stack string) Start {
	return Start{
		client:    client,
		networks:  networks,
		workspace: workspace,
		stack:     stack,
	}
}

func (s Start) Run(ctx context.Context, logs io.Writer, name, command string) (string, string, error) {
	env := []string{
		"LANG=en_US.UTF-8",
		"MEMORY_LIMIT=1024m",
		"PORT=8080",
		fmt.Sprintf(`VCAP_APPLICATION={"application_name":%[1]q,"name":%[1]q,"process_type":"web","limits":{"mem":1024}}`, name),
		"VCAP_PLATFORM_OPTIONS={}",
	}

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
			return "", "", fmt.Errorf("failed to marshal services json: %w", err)
		}

		env = append(env, fmt.Sprintf("VCAP_SERVICES=%s", content))
	} else {
		env = append(env, "VCAP_SERVICES={}")
	}

	if s.startCommand != "" {
		command = s.startCommand
	}

	if command == "" {
		return "", "", fmt.Errorf("error: Start command not specified")
	}

	containerConfig := container.Config{
		Image: fmt.Sprintf("cloudfoundry/%s:latest", s.stack),
		Cmd: []string{
			"/tmp/lifecycle/launcher",
			"app",
			command,
			"",
		},
		User:         "vcap",
		Env:          env,
		WorkingDir:   "/home/vcap",
		ExposedPorts: nat.PortSet{"8080/tcp": struct{}{}},
	}

	hostConfig := container.HostConfig{
		PublishAllPorts: true,
		NetworkMode:     container.NetworkMode(InternalNetworkName),
	}

	resp, err := s.client.ContainerCreate(ctx, &containerConfig, &hostConfig, nil, nil, name)
	if err != nil {
		return "", "", fmt.Errorf("failed to create running container: %w", err)
	}

	err = s.networks.Connect(ctx, resp.ID, BridgeNetworkName)
	if err != nil {
		return "", "", fmt.Errorf("failed to connect container to network: %w", err)
	}

	lifecycleTarball, err := os.Open(filepath.Join(s.workspace, "lifecycle", "lifecycle.tar.gz"))
	if err != nil {
		return "", "", fmt.Errorf("failed to open lifecycle: %w", err)
	}
	defer lifecycleTarball.Close()

	err = s.client.CopyToContainer(ctx, resp.ID, "/", lifecycleTarball, container.CopyToContainerOptions{})
	if err != nil {
		return "", "", fmt.Errorf("failed to copy lifecycle into container: %w", err)
	}

	dropletTarball, err := os.Open(filepath.Join(s.workspace, "droplets", fmt.Sprintf("%s.tar.gz", name)))
	if err != nil {
		return "", "", fmt.Errorf("failed to open droplet: %w", err)
	}
	defer dropletTarball.Close()

	err = s.client.CopyToContainer(ctx, resp.ID, "/home/vcap/", dropletTarball, container.CopyToContainerOptions{})
	if err != nil {
		return "", "", fmt.Errorf("failed to copy droplet into container: %w", err)
	}

	err = s.client.ContainerStart(ctx, resp.ID, container.StartOptions{})
	if err != nil {
		return "", "", fmt.Errorf("failed to start container: %w", err)
	}

	container, err := s.client.ContainerInspect(ctx, resp.ID)
	if err != nil {
		return "", "", fmt.Errorf("failed to inspect container: %w", err)
	}

	var externalURL string
	bindings, ok := container.NetworkSettings.Ports["8080/tcp"]
	if ok {
		for _, binding := range bindings {
			if binding.HostIP == "0.0.0.0" {
				externalURL = fmt.Sprintf("http://%s:%s", host(), binding.HostPort)
			}
		}
	}

	var internalURL string
	network, ok := container.NetworkSettings.Networks[InternalNetworkName]
	if ok {
		internalURL = fmt.Sprintf("http://%s:8080", network.IPAddress)
	}

	return externalURL, internalURL, nil
}

func host() string {
	val, ok := os.LookupEnv("DOCKER_HOST")
	if !ok || strings.HasPrefix(val, "unix://") {
		return "localhost"
	}

	url, err := url.Parse(val)
	if err != nil {
		return "localhost"
	}

	return url.Hostname()
}

func (s Start) WithStack(stack string) StartPhase {
	s.stack = stack
	return s
}

func (s Start) WithEnv(env map[string]string) StartPhase {
	s.env = env
	return s
}

func (s Start) WithServices(services map[string]map[string]interface{}) StartPhase {
	s.services = services
	return s
}

func (s Start) WithStartCommand(command string) StartPhase {
	s.startCommand = command
	return s
}
