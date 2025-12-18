package common

import "github.com/cloudfoundry/libbuildpack"

// Context holds shared dependencies for buildpack components
// Used by containers, frameworks, and JREs to access buildpack infrastructure
type Context struct {
	Stager    *libbuildpack.Stager
	Manifest  *libbuildpack.Manifest
	Installer *libbuildpack.Installer
	Log       *libbuildpack.Logger
	Command   *libbuildpack.Command
}
