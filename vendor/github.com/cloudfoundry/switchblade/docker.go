package switchblade

import (
	"bytes"
	"context"
	"fmt"

	"github.com/cloudfoundry/switchblade/internal/docker"
)

//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface InitializePhase --name DockerInitializePhase --output fakes/docker_initialize_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface DeinitializePhase --name DockerDeinitializePhase --output fakes/docker_deinitialize_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface SetupPhase --name DockerSetupPhase --output fakes/docker_setup_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface StagePhase --name DockerStagePhase --output fakes/docker_stage_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface StartPhase --name DockerStartPhase --output fakes/docker_start_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/docker --interface TeardownPhase --name DockerTeardownPhase --output fakes/docker_teardown_phase.go

func NewDocker(initialize docker.InitializePhase, deinitialize docker.DeinitializePhase, setup docker.SetupPhase, stage docker.StagePhase, start docker.StartPhase, teardown docker.TeardownPhase, client LogsClient) Platform {
	return Platform{
		initialize:   dockerInitializeProcess{initialize: initialize},
		deinitialize: dockerDeinitializeProcess{deinitialize: deinitialize},
		Deploy:       dockerDeployProcess{setup: setup, stage: stage, start: start, client: client},
		Delete:       dockerDeleteProcess{teardown: teardown},
	}
}

type dockerInitializeProcess struct {
	initialize docker.InitializePhase
}

func (p dockerInitializeProcess) Execute(buildpacks ...Buildpack) error {
	var bps []docker.Buildpack
	for _, buildpack := range buildpacks {
		bps = append(bps, docker.Buildpack{
			Name: buildpack.Name,
			URI:  buildpack.URI,
		})
	}

	return p.initialize.Run(bps)
}

type dockerDeinitializeProcess struct {
	deinitialize docker.DeinitializePhase
}

func (p dockerDeinitializeProcess) Execute() error {
	return p.deinitialize.Run()
}

type dockerDeployProcess struct {
	setup  docker.SetupPhase
	stage  docker.StagePhase
	start  docker.StartPhase
	client LogsClient
}

func (p dockerDeployProcess) WithBuildpacks(buildpacks ...string) DeployProcess {
	p.setup = p.setup.WithBuildpacks(buildpacks...)
	return p
}

func (p dockerDeployProcess) WithStack(stack string) DeployProcess {
	p.setup = p.setup.WithStack(stack)
	p.start = p.start.WithStack(stack)
	return p
}

func (p dockerDeployProcess) WithEnv(env map[string]string) DeployProcess {
	p.setup = p.setup.WithEnv(env)
	p.start = p.start.WithEnv(env)
	return p
}

func (p dockerDeployProcess) WithoutInternetAccess() DeployProcess {
	p.setup = p.setup.WithoutInternetAccess()
	return p
}

func (p dockerDeployProcess) WithServices(services map[string]Service) DeployProcess {
	s := make(map[string]map[string]interface{})
	for name, service := range services {
		s[name] = service
	}

	p.setup = p.setup.WithServices(s)
	p.start = p.start.WithServices(s)
	return p
}

func (p dockerDeployProcess) WithStartCommand(command string) DeployProcess {
	p.start = p.start.WithStartCommand(command)
	return p
}

func (p dockerDeployProcess) WithHealthCheckType(healthCheckType string) DeployProcess {
	// Docker platform doesn't use CF health check types, so this is a no-op
	return p
}

func (p dockerDeployProcess) Execute(name, path string) (Deployment, fmt.Stringer, error) {
	ctx := context.Background()
	logs := bytes.NewBuffer(nil)

	containerID, err := p.setup.Run(ctx, logs, name, path)
	if err != nil {
		return Deployment{}, logs, fmt.Errorf("failed to run setup phase: %w\n\nOutput:\n%s", err, logs)
	}

	command, err := p.stage.Run(ctx, logs, containerID, name)
	if err != nil {
		return Deployment{}, logs, fmt.Errorf("failed to run stage phase: %w\n\nOutput:\n%s", err, logs)
	}

	externalURL, internalURL, err := p.start.Run(ctx, logs, name, command)
	if err != nil {
		return Deployment{}, logs, fmt.Errorf("failed to run start phase: %w\n\nOutput:\n%s", err, logs)
	}

	return Deployment{
		Name:        name,
		ExternalURL: externalURL,
		InternalURL: internalURL,
		platform:    Docker,
		dockerCLI:   p.client,
	}, logs, nil
}

type dockerDeleteProcess struct {
	teardown docker.TeardownPhase
}

func (p dockerDeleteProcess) Execute(name string) error {
	ctx := context.Background()

	err := p.teardown.Run(ctx, name)
	if err != nil {
		return fmt.Errorf("failed to run teardown phase: %w", err)
	}

	return nil
}
