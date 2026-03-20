package pexec

import (
	"io"
	"os"
	"os/exec"
	"strings"
)

// Executable represents an executable on the $PATH.
type Executable struct {
	name string
}

// NewExecutable returns an instance of an Executable given the name of that
// executable. When given simply a name, the execuable will be looked up on the
// $PATH before execution. Alternatively, when given a path, the executable
// will use that path to invoke the executable file directly.
func NewExecutable(name string) Executable {
	return Executable{
		name: name,
	}
}

// Execute invokes the executable with a set of Execution arguments.
func (e Executable) Execute(execution Execution) error {
	envPath := os.Getenv("PATH")

	if execution.Env != nil {
		var path string
		for _, variable := range execution.Env {
			if strings.HasPrefix(variable, "PATH=") {
				path = strings.TrimPrefix(variable, "PATH=")
			}
		}
		if path != "" {
			os.Setenv("PATH", path)
		}
	}

	executable, err := exec.LookPath(e.name)
	if err != nil {
		return err
	}

	os.Setenv("PATH", envPath)

	cmd := exec.Command(executable, execution.Args...)

	if execution.Dir != "" {
		cmd.Dir = execution.Dir
	}

	if len(execution.Env) > 0 {
		cmd.Env = execution.Env
	}

	cmd.Stdout = execution.Stdout
	cmd.Stderr = execution.Stderr
	cmd.Stdin = execution.Stdin

	return cmd.Run()
}

// Execution is the set of configurable options for a given execution of the
// executable.
type Execution struct {
	// Args is a list of the arguments to be passed to the executable.
	Args []string

	// Dir is the path to a directory from with the executable should be invoked.
	// If Dir is not set, the current working directory will be used.
	Dir string

	// Env is the set of environment variables that make up the environment for
	// the execution. If Env is not set, the existing os.Environ value will be
	// used.
	Env []string

	// Stdout is where the output of stdout will be written during the execution.
	Stdout io.Writer

	// Stderr is where the output of stderr will be written during the execution.
	Stderr io.Writer

	// Stdin is where the input of stdin will be read during the execution.
	Stdin io.Reader
}
