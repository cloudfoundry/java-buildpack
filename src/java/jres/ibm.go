package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// IBMJRE implements the JRE interface for IBM JRE.
type IBMJRE struct{ BaseJRE }

// NewIBMJRE creates a new IBM JRE provider.
func NewIBMJRE(ctx *common.Context) *IBMJRE {
	b := newBaseJRE(ctx, "IBM JRE", "ibm", []string{"ibm-java"}, []string{"jre"}, "")
	b.extraFinalizeOpts = func() string { return "-Xtune:virtualized -Xshareclasses:none" }
	return &IBMJRE{b}
}
