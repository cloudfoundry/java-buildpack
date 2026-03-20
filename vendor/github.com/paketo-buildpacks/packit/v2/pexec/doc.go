// Package pexec provides a mechanism for invoking a program executable with a
// varying set of arguments.
//
// Below is an example showing how you might invoke the `echo` executable with arguments;
//
//   package main
//
//   import (
//   	"os"
//
//   	"github.com/paketo-buildpacks/packit/v2/pexec"
//   )
//
//   func main() {
//   	echo := pexec.NewExecutable("echo")
//
//   	err := echo.Execute(pexec.Execution{
//   		Args:   []string{"hello from pexec"},
//   		Stdout: os.Stdout,
//   	})
//   	if err != nil {
//   		panic(err)
//   	}
//
//   	// Output: hello from pexec
//   }
//
package pexec
