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

type StagePhase interface {
	Run(logs io.Writer, home, name string) (url string, err error)
}

type Stage struct {
	cli Executable
}

func NewStage(cli Executable) Stage {
	return Stage{
		cli: cli,
	}
}

func (s Stage) Run(logs io.Writer, home, name string) (string, error) {
	env := append(os.Environ(), fmt.Sprintf("CF_HOME=%s", home))

	err := s.cli.Execute(pexec.Execution{
		Args:   []string{"start", name},
		Stdout: logs,
		Stderr: logs,
		Env:    env,
	})
	if err != nil {
		// In CF API v3, staging failure logs are not automatically captured in stdout/stderr
		// We need to fetch them explicitly using 'cf logs --recent'
		recentLogs, logErr := FetchRecentLogs(s.cli, home, name)
		if logErr == nil && len(recentLogs) > 0 {
			// Append recent logs to the main logs buffer
			_, _ = logs.Write([]byte("\n--- Recent Logs (cf logs --recent) ---\n"))
			_, _ = logs.Write([]byte(recentLogs))
		}

		return "", fmt.Errorf("failed to start: %w\n\nOutput:\n%s", err, logs)
	}

	buffer := bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"app", name, "--guid"},
		Stdout: buffer,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to fetch guid: %w\n\nOutput:\n%s", err, buffer)
	}

	guid := strings.TrimSpace(buffer.String())
	buffer = bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"curl", fmt.Sprintf("/v3/apps/%s/routes", guid)},
		Stdout: buffer,
		Stderr: logs,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to fetch routes: %w\n\nOutput:\n%s", err, buffer)
	}

	var routes struct {
		Resources []struct {
			URL      string `json:"url"`
			Protocol string `json:"protocol"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&routes)
	if err != nil {
		return "", fmt.Errorf("failed to parse routes: %w\n\nOutput:\n%s", err, buffer)
	}

	var url string
	if len(routes.Resources) > 0 {
		url = fmt.Sprintf("http://%s", routes.Resources[0].URL)
	}

	return url, nil
}
