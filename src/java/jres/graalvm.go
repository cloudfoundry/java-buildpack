package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// GraalVMJRE implements the JRE interface for GraalVM.
type GraalVMJRE struct{ BaseJRE }

// NewGraalVMJRE creates a new GraalVM JRE provider.
func NewGraalVMJRE(ctx *common.Context) *GraalVMJRE {
	b := newBaseJRE(ctx, "GraalVM", "graalvm", []string{"graalvm"}, nil, "(ensure repository_root is configured)")
	b.extraFinalizeOpts = func() string { return "-XX:ActiveProcessorCount=$(nproc)" }
	return &GraalVMJRE{b}
}
