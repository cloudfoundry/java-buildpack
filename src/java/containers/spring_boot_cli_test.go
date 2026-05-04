package containers_test

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/containers"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Spring Boot CLI Container", func() {
	var (
		ctx       *common.Context
		container *containers.SpringBootCLIContainer
		buildDir  string
		depsDir   string
		cacheDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())

		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())

		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())

		err = os.MkdirAll(filepath.Join(depsDir, "0"), 0755)
		Expect(err).NotTo(HaveOccurred())

		logger := libbuildpack.NewLogger(os.Stdout)
		manifest := &libbuildpack.Manifest{}
		installer := &libbuildpack.Installer{}
		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
		command := &libbuildpack.Command{}

		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: installer,
			Log:       logger,
			Command:   command,
		}

		container = containers.NewSpringBootCLIContainer(ctx)
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(cacheDir)
	})

	Describe("Finalize", func() {
		It("writes a profile.d script that exports SERVER_PORT=$PORT so the variable is shell-expanded at runtime", func() {
			err := container.Finalize()
			Expect(err).NotTo(HaveOccurred())

			profileScript := filepath.Join(depsDir, "0", "profile.d", "spring_boot_cli_server_port.sh")
			data, err := os.ReadFile(profileScript)
			Expect(err).NotTo(HaveOccurred())
			Expect(string(data)).To(Equal("export SERVER_PORT=$PORT\n"))

			// Verify $PORT is actually shell-expanded at runtime (not left as literal "$PORT").
			// Simulates what CF's launcher does: source the profile.d script with PORT set in env.
			cmd := exec.Command("bash", "-c", fmt.Sprintf("PORT=8080 . %s && echo $SERVER_PORT", profileScript))
			out, bashErr := cmd.Output()
			Expect(bashErr).NotTo(HaveOccurred())
			Expect(strings.TrimSpace(string(out))).To(Equal("8080"),
				"SERVER_PORT should be the expanded value of $PORT, not the literal string \"$PORT\"")
		})
	})
})
