//go:build cfenv_artifact

// This test verifies a *necessary condition* for the buildpack's automatic "cloud"
// Spring profile behaviour: the java-cfenv artifact the manifest ships must register
// io.pivotal.cfenv.profile.CloudProfileApplicationListener as a Spring ApplicationListener
// (via META-INF/spring.factories). That listener lives only in the java-cfenv-all module;
// the bare java-cfenv core module does not carry it, which silently drops the "cloud"
// profile (see cloudfoundry/java-buildpack#1349).
//
// It downloads each shipped jar, verifies its SHA-256 against the manifest (which also
// guards against duplicate/mismatched mirror entries), then inspects spring.factories.
//
// It is network-bound, so it is excluded from the default unit suite by the cfenv_artifact
// build tag. Run explicitly:
//
//	go test -tags cfenv_artifact ./src/java/frameworks/
package frameworks_test

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"gopkg.in/yaml.v2"
)

const cloudProfileListener = "io.pivotal.cfenv.profile.CloudProfileApplicationListener"

type manifestDependency struct {
	Name    string `yaml:"name"`
	Version string `yaml:"version"`
	URI     string `yaml:"uri"`
	SHA256  string `yaml:"sha256"`
}

type manifestFile struct {
	Dependencies []manifestDependency `yaml:"dependencies"`
}

var _ = Describe("Java CF Env artifact", func() {
	var deps []manifestDependency

	BeforeEach(func() {
		deps = nil

		manifestPath, err := filepath.Abs(filepath.Join("..", "..", "..", "manifest.yml"))
		Expect(err).NotTo(HaveOccurred())

		raw, err := os.ReadFile(manifestPath)
		Expect(err).NotTo(HaveOccurred())

		var m manifestFile
		Expect(yaml.Unmarshal(raw, &m)).To(Succeed())

		for _, d := range m.Dependencies {
			if d.Name == "java-cfenv" && d.URI != "" {
				deps = append(deps, d)
			}
		}
		Expect(deps).NotTo(BeEmpty(), "no java-cfenv dependency entries with a uri found in manifest.yml")
	})

	It("ships a jar that registers the cloud-profile ApplicationListener", func() {
		for _, dep := range deps {
			By("checking java-cfenv " + dep.Version)

			jar := downloadToTemp(dep.URI)
			defer os.Remove(jar)

			Expect(fileSHA256(jar)).To(Equal(dep.SHA256),
				"java-cfenv %s: downloaded bytes do not match manifest sha256 (%s)", dep.Version, dep.URI)

			factories, ok := readZipEntry(jar, "META-INF/spring.factories")
			Expect(ok).To(BeTrue(),
				"java-cfenv %s: jar has no META-INF/spring.factories — this is the bare core module, "+
					"which cannot auto-activate the 'cloud' profile; ship java-cfenv-all instead", dep.Version)

			Expect(factories).To(ContainSubstring(cloudProfileListener),
				"java-cfenv %s: spring.factories does not register %s — the 'cloud' profile will not be "+
					"activated automatically; ship java-cfenv-all instead", dep.Version, cloudProfileListener)

			Expect(registersAsApplicationListener(factories, cloudProfileListener)).To(BeTrue(),
				"java-cfenv %s: %s is present but not registered under "+
					"org.springframework.context.ApplicationListener", dep.Version, cloudProfileListener)
		}
	})
})

// registersAsApplicationListener reports whether class is listed under the
// org.springframework.context.ApplicationListener key, accounting for backslash
// line continuations used in spring.factories files.
func registersAsApplicationListener(factories, class string) bool {
	const key = "org.springframework.context.ApplicationListener"
	joined := strings.ReplaceAll(factories, "\\\n", "")
	for _, line := range strings.Split(joined, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, key+"=") {
			return strings.Contains(line, class)
		}
	}
	return false
}

func downloadToTemp(uri string) string {
	GinkgoHelper()

	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(uri)
	Expect(err).NotTo(HaveOccurred(), "download %s", uri)
	defer resp.Body.Close()
	Expect(resp.StatusCode).To(Equal(http.StatusOK), "download %s returned %d", uri, resp.StatusCode)

	f, err := os.CreateTemp("", "java-cfenv-*.jar")
	Expect(err).NotTo(HaveOccurred())
	defer f.Close()

	_, err = io.Copy(f, resp.Body)
	Expect(err).NotTo(HaveOccurred())

	return f.Name()
}

func fileSHA256(path string) string {
	GinkgoHelper()

	f, err := os.Open(path)
	Expect(err).NotTo(HaveOccurred())
	defer f.Close()

	h := sha256.New()
	_, err = io.Copy(h, f)
	Expect(err).NotTo(HaveOccurred())

	return hex.EncodeToString(h.Sum(nil))
}

func readZipEntry(jarPath, entry string) (string, bool) {
	GinkgoHelper()

	r, err := zip.OpenReader(jarPath)
	Expect(err).NotTo(HaveOccurred())
	defer r.Close()

	for _, f := range r.File {
		if f.Name == entry {
			rc, err := f.Open()
			Expect(err).NotTo(HaveOccurred())
			defer rc.Close()

			data, err := io.ReadAll(rc)
			Expect(err).NotTo(HaveOccurred())
			return string(data), true
		}
	}
	return "", false
}
