package jres

import "github.com/cloudfoundry/java-buildpack/src/java/common"

// OracleJRE implements the JRE interface for Oracle JRE.
type OracleJRE struct{ BaseJRE }

// NewOracleJRE creates a new Oracle JRE provider.
func NewOracleJRE(ctx *common.Context) *OracleJRE {
	return &OracleJRE{newBaseJRE(ctx, "Oracle JRE", "oracle", []string{"jdk", "jre"}, nil, "")}
}
