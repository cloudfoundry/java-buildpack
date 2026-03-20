package docker

import (
	"context"
	"fmt"
)

const (
	InternalNetworkName = "switchblade-internal"
)

//go:generate faux --interface InitializeNetworkManager --output fakes/initialize_network_manager.go
type InitializeNetworkManager interface {
	Create(ctx context.Context, name, driver string, internal bool) error
}

type InitializePhase interface {
	Run([]Buildpack) error
}

type Initialize struct {
	registry BPRegistry
	network  InitializeNetworkManager
}

func NewInitialize(registry BPRegistry, network InitializeNetworkManager) Initialize {
	return Initialize{
		registry: registry,
		network:  network,
	}
}

func (i Initialize) Run(buildpacks []Buildpack) error {
	i.registry.Override(buildpacks...)

	ctx := context.Background()

	err := i.network.Create(ctx, InternalNetworkName, "bridge", true)
	if err != nil {
		return fmt.Errorf("failed to create network: %w", err)
	}

	return nil
}
