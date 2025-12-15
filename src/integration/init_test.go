package integration_test

import (
	"flag"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/cloudfoundry/switchblade"
	"github.com/onsi/gomega/format"
	"github.com/sclevine/spec"
	"github.com/sclevine/spec/report"

	. "github.com/onsi/gomega"
)

var settings struct {
	Buildpack struct {
		Version string
		Path    string
	}

	Cached               bool
	Serial               bool
	KeepFailedContainers bool
	FixturesPath         string
	GitHubToken          string
	Platform             string
	Stack                string
}

func init() {
	flag.BoolVar(&settings.Cached, "cached", false, "run cached buildpack tests")
	flag.BoolVar(&settings.Serial, "serial", false, "run serial buildpack tests")
	flag.BoolVar(&settings.KeepFailedContainers, "keep-failed-containers", false, "preserve failed test containers for debugging")
	flag.StringVar(&settings.Platform, "platform", "cf", `switchblade platform to test against ("cf" or "docker")`)
	flag.StringVar(&settings.GitHubToken, "github-token", "", "use the token to make GitHub API requests")
	flag.StringVar(&settings.Stack, "stack", "cflinuxfs4", "stack to use as default when pushing apps")
}

func TestIntegration(t *testing.T) {
	var Expect = NewWithT(t).Expect

	format.MaxLength = 0
	SetDefaultEventuallyTimeout(20 * time.Second)

	root, err := filepath.Abs("./../../")
	Expect(err).NotTo(HaveOccurred())

	fixtures := filepath.Join(root, "src", "integration", "testdata")

	platform, err := switchblade.NewPlatform(settings.Platform, settings.GitHubToken, settings.Stack)
	Expect(err).NotTo(HaveOccurred())

	buildpackFile := os.Getenv("BUILDPACK_FILE")
	if buildpackFile == "" {
		t.Fatal("BUILDPACK_FILE environment variable is required")
	}

	err = platform.Initialize(
		switchblade.Buildpack{
			Name: "java_buildpack",
			URI:  buildpackFile,
		},
	)
	Expect(err).NotTo(HaveOccurred())

	var suite spec.Suite
	if settings.Serial {
		suite = spec.New("integration", spec.Report(report.Terminal{}), spec.Sequential())
	} else {
		suite = spec.New("integration", spec.Report(report.Terminal{}), spec.Parallel())
	}

	// Core container tests
	suite("Tomcat", testTomcat(platform, fixtures))
	suite("SpringBoot", testSpringBoot(platform, fixtures))
	suite("JavaMain", testJavaMain(platform, fixtures))
	suite("DistZip", testDistZip(platform, fixtures))

	suite("Groovy", testGroovy(platform, fixtures))
	suite("Ratpack", testRatpack(platform, fixtures))
	suite("Play", testPlay(platform, fixtures))
	suite("SpringBootCLI", testSpringBootCLI(platform, fixtures))

	// Framework tests (APM agents, security providers, etc.)
	suite("Frameworks", testFrameworks(platform, fixtures))

	suite.Run(t)

	Expect(platform.Deinitialize()).To(Succeed())
}
