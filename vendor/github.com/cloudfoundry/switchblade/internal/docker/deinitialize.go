package docker

import (
	"context"
	"fmt"
)

//go:generate faux --interface DeinitializeNetworkManager --output fakes/deinitialize_network_manager.go
type DeinitializeNetworkManager interface {
	Delete(ctx context.Context, name string) error
}

type DeinitializePhase interface {
	Run() error
}

type Deinitialize struct {
	network DeinitializeNetworkManager
}

func NewDeinitialize(network DeinitializeNetworkManager) Deinitialize {
	return Deinitialize{
		network: network,
	}
}

func (d Deinitialize) Run() error {
	ctx := context.Background()

	err := d.network.Delete(ctx, InternalNetworkName)
	if err != nil {
		return fmt.Errorf("failed to delete network: %w", err)
	}

	return nil
}
