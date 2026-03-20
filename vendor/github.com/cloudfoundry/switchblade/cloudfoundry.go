package switchblade

import (
	"bytes"
	"fmt"
	"path/filepath"

	"github.com/cloudfoundry/switchblade/internal/cloudfoundry"
)

//go:generate faux --package github.com/cloudfoundry/switchblade/internal/cloudfoundry --interface InitializePhase --name CloudFoundryInitializePhase --output fakes/cloudfoundry_initialize_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/cloudfoundry --interface DeinitializePhase --name CloudFoundryDeinitializePhase --output fakes/cloudfoundry_deinitialize_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/cloudfoundry --interface SetupPhase --name CloudFoundrySetupPhase --output fakes/cloudfoundry_setup_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/cloudfoundry --interface StagePhase --name CloudFoundryStagePhase --output fakes/cloudfoundry_stage_phase.go
//go:generate faux --package github.com/cloudfoundry/switchblade/internal/cloudfoundry --interface TeardownPhase --name CloudFoundryTeardownPhase --output fakes/cloudfoundry_teardown_phase.go

func NewCloudFoundry(initialize cloudfoundry.InitializePhase, deinitialize cloudfoundry.DeinitializePhase, setup cloudfoundry.SetupPhase, stage cloudfoundry.StagePhase, teardown cloudfoundry.TeardownPhase, workspace string, cli cloudfoundry.Executable) Platform {
	return Platform{
		initialize:   cloudFoundryInitializeProcess{initialize: initialize},
		deinitialize: cloudFoundryDeinitializeProcess{deinitialize: deinitialize},
		Deploy:       cloudFoundryDeployProcess{setup: setup, stage: stage, workspace: workspace, cli: cli},
		Delete:       cloudFoundryDeleteProcess{teardown: teardown, workspace: workspace},
	}
}

type cloudFoundryInitializeProcess struct {
	initialize cloudfoundry.InitializePhase
}

func (p cloudFoundryInitializeProcess) Execute(buildpacks ...Buildpack) error {
	var bps []cloudfoundry.Buildpack
	for _, buildpack := range buildpacks {
		bps = append(bps, cloudfoundry.Buildpack{
			Name: buildpack.Name,
			URI:  buildpack.URI,
		})
	}

	return p.initialize.Run(bps)
}

type cloudFoundryDeinitializeProcess struct {
	deinitialize cloudfoundry.DeinitializePhase
}

func (p cloudFoundryDeinitializeProcess) Execute() error {
	return p.deinitialize.Run()
}

type cloudFoundryDeployProcess struct {
	setup     cloudfoundry.SetupPhase
	stage     cloudfoundry.StagePhase
	workspace string
	cli       cloudfoundry.Executable
}

func (p cloudFoundryDeployProcess) WithBuildpacks(buildpacks ...string) DeployProcess {
	p.setup = p.setup.WithBuildpacks(buildpacks...)
	return p
}

func (p cloudFoundryDeployProcess) WithStack(stack string) DeployProcess {
	p.setup = p.setup.WithStack(stack)
	return p
}

func (p cloudFoundryDeployProcess) WithEnv(env map[string]string) DeployProcess {
	p.setup = p.setup.WithEnv(env)
	return p
}

func (p cloudFoundryDeployProcess) WithoutInternetAccess() DeployProcess {
	p.setup = p.setup.WithoutInternetAccess()
	return p
}

func (p cloudFoundryDeployProcess) WithServices(services map[string]Service) DeployProcess {
	s := make(map[string]map[string]interface{})
	for name, service := range services {
		s[name] = service
	}

	p.setup = p.setup.WithServices(s)
	return p
}

func (p cloudFoundryDeployProcess) WithStartCommand(command string) DeployProcess {
	p.setup = p.setup.WithStartCommand(command)
	return p
}

func (p cloudFoundryDeployProcess) WithHealthCheckType(healthCheckType string) DeployProcess {
	p.setup = p.setup.WithHealthCheckType(healthCheckType)
	return p
}

func (p cloudFoundryDeployProcess) Execute(name, source string) (Deployment, fmt.Stringer, error) {
	logs := bytes.NewBuffer(nil)
	home := filepath.Join(p.workspace, name)

	internalURL, err := p.setup.Run(logs, home, name, source)
	if err != nil {
		return Deployment{}, logs, err
	}

	externalURL, err := p.stage.Run(logs, home, name)
	if err != nil {
		return Deployment{}, logs, err
	}

	return Deployment{
		Name:        name,
		ExternalURL: externalURL,
		InternalURL: internalURL,
		platform:    CloudFoundry,
		workspace:   home,
		cfCLI:       p.cli,
	}, logs, nil
}

type cloudFoundryDeleteProcess struct {
	teardown  cloudfoundry.TeardownPhase
	workspace string
}

func (p cloudFoundryDeleteProcess) Execute(name string) error {
	return p.teardown.Run(filepath.Join(p.workspace, name), name)
}
