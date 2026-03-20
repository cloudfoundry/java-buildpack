package libbuildpack

import (
	"io"
	"os"
	"os/exec"
)

type Command struct {
}

func (c *Command) Execute(dir string, stdout io.Writer, stderr io.Writer, program string, args ...string) error {
	cmd := exec.Command(program, args...)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	cmd.Dir = dir

	return cmd.Run()
}

func (c *Command) Output(dir string, program string, args ...string) (string, error) {
	cmd := exec.Command(program, args...)
	cmd.Stderr = os.Stderr // TODO remove this line
	cmd.Dir = dir

	output, err := cmd.Output()
	return string(output), err
}

func (c *Command) Run(cmd *exec.Cmd) error {
	return cmd.Run()
}

func (c *Command) RunWithOutput(cmd *exec.Cmd) ([]byte, error) {
	return cmd.Output()
}
