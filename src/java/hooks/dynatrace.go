package hooks

import (
	"github.com/Dynatrace/libbuildpack-dynatrace"
	"github.com/cloudfoundry/libbuildpack"
)

func init() {
	libbuildpack.AddHook(dynatrace.NewHook("java", "process"))
}
