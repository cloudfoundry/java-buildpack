package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// ZuluJRE implements the JRE interface for Azul Zulu OpenJDK.
type ZuluJRE struct{ BaseJRE }

// NewZuluJRE creates a new Zulu JRE provider.
func NewZuluJRE(ctx *common.Context) *ZuluJRE {
	return &ZuluJRE{newBaseJRE(ctx, "Zulu", "zulu", []string{"zulu"}, nil, "")}
}
