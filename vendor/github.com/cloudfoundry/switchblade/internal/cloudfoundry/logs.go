package cloudfoundry

import (
	"bytes"
	"fmt"
	"os"

	"github.com/paketo-buildpacks/packit/v2/pexec"
)

// FetchRecentLogs retrieves recent application logs using 'cf logs --recent'.
// This is a shared helper used for both staging failures and runtime log retrieval.
func FetchRecentLogs(cli Executable, home, appName string) (string, error) {
	env := append(os.Environ(), fmt.Sprintf("CF_HOME=%s", home))
	buffer := bytes.NewBuffer(nil)

	err := cli.Execute(pexec.Execution{
		Args:   []string{"logs", appName, "--recent"},
		Stdout: buffer,
		Stderr: buffer,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to retrieve logs: %w", err)
	}

	return buffer.String(), nil
}
