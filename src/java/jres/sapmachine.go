package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// SapMachineJRE implements the JRE interface for SAP Machine OpenJDK.
type SapMachineJRE struct{ BaseJRE }

// NewSapMachineJRE creates a new SAP Machine JRE provider.
func NewSapMachineJRE(ctx *common.Context) *SapMachineJRE {
	return &SapMachineJRE{newBaseJRE(ctx, "SapMachine", "sapmachine", []string{"sapmachine"}, nil, "")}
}
