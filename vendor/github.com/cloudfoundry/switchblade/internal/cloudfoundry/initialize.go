package cloudfoundry

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strconv"

	"github.com/paketo-buildpacks/packit/v2/pexec"
)

type Buildpack struct {
	Name string
	URI  string
}

type InitializePhase interface {
	Run([]Buildpack) error
}

type Initialize struct {
	cli   Executable
	stack string
}

func NewInitialize(cli Executable, stack string) Initialize {
	return Initialize{cli: cli, stack: stack}
}

func (i Initialize) Run(buildpacks []Buildpack) error {
	logs := bytes.NewBuffer(nil)

	for _, buildpack := range buildpacks {
		position := "1000"

		buffer := bytes.NewBuffer(nil)
		err := i.cli.Execute(pexec.Execution{
			Args:   []string{"curl", fmt.Sprintf("/v3/buildpacks?names=%s", buildpack.Name)},
			Stdout: io.MultiWriter(buffer, logs),
			Stderr: logs,
		})
		if err == nil {
			var payload struct {
				Resources []struct {
					Position int `json:"position"`
				} `json:"resources"`
			}
			err = json.NewDecoder(buffer).Decode(&payload)
			if err != nil {
				return fmt.Errorf("failed to parse buildpacks: %w", err)
			}

			if len(payload.Resources) > 0 {
				position = strconv.Itoa(payload.Resources[0].Position)
			}

			err = i.cli.Execute(pexec.Execution{
				Args:   []string{"delete-buildpack", "-f", buildpack.Name},
				Stdout: logs,
				Stderr: logs,
			})
			if err != nil {
				return fmt.Errorf("failed to delete buildpack: %s\n\nOutput:\n%s", err, logs)
			}
		}

		err = i.cli.Execute(pexec.Execution{
			Args:   []string{"create-buildpack", buildpack.Name, buildpack.URI, position},
			Stdout: logs,
			Stderr: logs,
		})
		if err != nil {
			return fmt.Errorf("failed to create buildpack: %w\n\nOutput:\n%s", err, logs)
		}
	}

	return nil
}
