package cloudfoundry

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/paketo-buildpacks/packit/v2/pexec"
)

type TeardownPhase interface {
	Run(home, name string) error
}

type Teardown struct {
	cli Executable
}

func NewTeardown(cli Executable) Teardown {
	return Teardown{
		cli: cli,
	}
}

func (t Teardown) Run(home, name string) error {
	logs := bytes.NewBuffer(nil)
	env := append(os.Environ(), fmt.Sprintf("CF_HOME=%s", home))

	err := t.cli.Execute(pexec.Execution{
		Args:   []string{"delete-org", name, "-f"},
		Stdout: logs,
		Stderr: logs,
		Env:    env,
	})
	if err != nil {
		return fmt.Errorf("failed to delete-org: %w\n\nOutput:\n%s", err, logs)
	}

	err = t.cli.Execute(pexec.Execution{
		Args:   []string{"delete-security-group", name, "-f"},
		Stdout: logs,
		Stderr: logs,
		Env:    env,
	})
	if err != nil {
		return fmt.Errorf("failed to delete-security-group: %w\n\nOutput:\n%s", err, logs)
	}

	buffer := bytes.NewBuffer(nil)
	err = t.cli.Execute(pexec.Execution{
		Args:   []string{"curl", "/v3/service_instances"},
		Stdout: io.MultiWriter(buffer, logs),
		Stderr: logs,
		Env:    env,
	})
	if err != nil {
		return fmt.Errorf("failed to curl /v3/service_instances: %w\n\nOutput:\n%s", err, logs)
	}

	var serviceInstances struct {
		Resources []struct {
			Name string `json:"name"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&serviceInstances)
	if err != nil {
		return fmt.Errorf("failed to decode service instance json: %w", err)
	}

	for _, service := range serviceInstances.Resources {
		if strings.HasPrefix(service.Name, fmt.Sprintf("%s-", name)) {
			err = t.cli.Execute(pexec.Execution{
				Args:   []string{"delete-service", service.Name, "-f"},
				Stdout: logs,
				Stderr: logs,
				Env:    env,
			})
			if err != nil {
				return fmt.Errorf("failed to delete-service: %w\n\nOutput:\n%s", err, logs)
			}
		}
	}

	err = os.RemoveAll(home)
	if err != nil {
		return err
	}

	return nil
}
