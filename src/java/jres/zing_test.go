package jres_test

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func writeTarGz(path string, files map[string]string) {
	f, err := os.Create(path)
	Expect(err).NotTo(HaveOccurred())
	defer f.Close()
	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)
	for name, content := range files {
		Expect(tw.WriteHeader(&tar.Header{Name: name, Mode: 0755, Size: int64(len(content))})).To(Succeed())
		_, err := tw.Write([]byte(content))
		Expect(err).NotTo(HaveOccurred())
	}
	Expect(tw.Close()).To(Succeed())
	Expect(gz.Close()).To(Succeed())
}

var _ = Describe("Zing JRE", func() {
	var (
		ctx                                      *common.Context
		buildDir, cacheDir, depsDir, manifestDir string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())
		manifestDir, err = os.MkdirTemp("", "manifest")
		Expect(err).NotTo(HaveOccurred())
		os.Setenv("CF_STACK", "cflinuxfs4")

		tarball := filepath.Join(manifestDir, "zing.tar.gz")
		writeTarGz(tarball, map[string]string{
			"zing-jdk/bin/java":                   "#!/bin/sh\n",
			"zing-jdk/lib/security/blocked.certs": "Algorithm=SHA-256\n" + vendorFingerprint + "\n",
		})
		data, err := os.ReadFile(tarball)
		Expect(err).NotTo(HaveOccurred())
		sum := sha256.Sum256(data)

		Expect(os.WriteFile(filepath.Join(manifestDir, "VERSION"), []byte("1.0.0"), 0644)).To(Succeed())
		Expect(os.WriteFile(filepath.Join(manifestDir, "manifest.yml"), []byte(fmt.Sprintf(`---
language: java
default_versions:
- name: zing
  version: 21.x
dependencies:
- name: zing
  version: 21.0.1
  uri: https://example.com/zing.tar.gz
  file: zing.tar.gz
  sha256: %s
  cf_stacks:
  - cflinuxfs4
`, hex.EncodeToString(sum[:]))), 0644)).To(Succeed())

		logger := libbuildpack.NewLogger(GinkgoWriter)
		manifest, err := libbuildpack.NewManifest(manifestDir, logger, time.Now())
		Expect(err).NotTo(HaveOccurred())
		stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
		ctx = &common.Context{
			Stager:    stager,
			Manifest:  manifest,
			Installer: libbuildpack.NewInstaller(manifest),
			Log:       logger,
			Command:   &libbuildpack.Command{},
		}
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.RemoveAll(manifestDir)
		os.Unsetenv("CF_STACK")
	})

	It("adds blocked certificates during Supply", func() {
		Expect(jres.NewZingJRE(ctx).Supply()).To(Succeed())

		data, err := os.ReadFile(filepath.Join(depsDir, "0", "jre", "zing-jdk", "lib", "security", "blocked.certs"))
		Expect(err).NotTo(HaveOccurred())
		Expect(string(data)).To(HavePrefix("Algorithm=SHA-256\n" + vendorFingerprint + "\n"))
		for _, fp := range embeddedFingerprints() {
			Expect(string(data)).To(ContainSubstring(fp))
		}
	})
})
