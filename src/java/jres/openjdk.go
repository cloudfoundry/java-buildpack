package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// OpenJDKJRE implements the JRE interface for OpenJDK.
type OpenJDKJRE struct{ BaseJRE }

// NewOpenJDKJRE creates a new OpenJDK JRE provider.
func NewOpenJDKJRE(ctx *common.Context) *OpenJDKJRE {
	return &OpenJDKJRE{newBaseJRE(ctx, "OpenJDK", "openjdk", []string{"jdk", "jre"}, nil, "")}
}
