package docker

import (
	"context"
	"fmt"
	"sync"

	"github.com/docker/docker/api/types/network"
	"github.com/docker/docker/errdefs"
)

//go:generate faux --interface NetworkManagementClient --output fakes/network_management_client.go
type NetworkManagementClient interface {
	NetworkList(ctx context.Context, options network.ListOptions) ([]network.Inspect, error)
	NetworkCreate(ctx context.Context, name string, options network.CreateOptions) (network.CreateResponse, error)
	NetworkConnect(ctx context.Context, networkID, containerID string, config *network.EndpointSettings) error
	NetworkRemove(ctx context.Context, networkID string) error
}

type NetworkManager struct {
	client NetworkManagementClient
	m      *sync.Mutex
}

func NewNetworkManager(client NetworkManagementClient) NetworkManager {
	return NetworkManager{
		client: client,
		m:      &sync.Mutex{},
	}
}

func (m NetworkManager) Create(ctx context.Context, name, driver string, internal bool) error {
	m.m.Lock()
	defer m.m.Unlock()

	networks, err := m.client.NetworkList(ctx, network.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list networks: %w", err)
	}

	for _, nw := range networks {
		if nw.Name == name {
			return nil
		}
	}

	_, err = m.client.NetworkCreate(ctx, name, network.CreateOptions{
		Driver:   driver,
		Internal: internal,
	})
	if err != nil {
		return fmt.Errorf("failed to create network: %w", err)
	}

	return nil
}

func (m NetworkManager) Connect(ctx context.Context, containerID, name string) error {
	m.m.Lock()
	defer m.m.Unlock()

	networks, err := m.client.NetworkList(ctx, network.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list networks: %w", err)
	}

	for _, nw := range networks {
		if nw.Name == name {
			err = m.client.NetworkConnect(ctx, nw.ID, containerID, nil)
			if err != nil {
				return fmt.Errorf("failed to connect container to network: %w", err)
			}

			return nil
		}
	}

	return fmt.Errorf("failed to connect container to network: no such network %q", name)
}

func (m NetworkManager) Delete(ctx context.Context, name string) error {
	m.m.Lock()
	defer m.m.Unlock()

	networks, err := m.client.NetworkList(ctx, network.ListOptions{})
	if err != nil {
		return fmt.Errorf("failed to list networks: %w", err)
	}

	for _, nw := range networks {
		if nw.Name == name {
			err = m.client.NetworkRemove(ctx, nw.ID)
			if err != nil && !errdefs.IsForbidden(err) {
				return fmt.Errorf("failed to delete network: %w", err)
			}

			return nil
		}
	}

	return nil
}
