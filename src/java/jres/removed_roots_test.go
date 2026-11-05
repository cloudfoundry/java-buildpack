package jres_test

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Removed root certificates", func() {
	var (
		ctx       *common.Context
		javaHome  string
		logBuffer *bytes.Buffer
	)

	// The fake keytool prints listing.txt for -list and records the alias of each -delete in calls.log.
	const fakeKeytool = `#!/bin/sh
dir="$(dirname "$0")/.."
case " $* " in
*" -list "*) cat "$dir/listing.txt" ;;
*" -delete "*)
	while [ $# -gt 0 ]; do
		[ "$1" = "-alias" ] && echo "$2" >> "$dir/calls.log"
		shift
	done ;;
esac
`

	aaaPEM := func() string {
		data, err := os.ReadFile(filepath.Join("testdata", "aaa-certificate-services.pem"))
		Expect(err).NotTo(HaveOccurred())
		return string(data)
	}

	unrelatedPEM := func() string {
		key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
		Expect(err).NotTo(HaveOccurred())
		template := &x509.Certificate{SerialNumber: big.NewInt(1), Subject: pkix.Name{CommonName: "Unrelated Root"}}
		der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
		Expect(err).NotTo(HaveOccurred())
		return string(pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}))
	}

	entry := func(alias, certificate string) string {
		return "Alias name: " + alias + "\nCreation date: Jan 1, 2026\nEntry type: trustedCertEntry\n\n" + certificate + "\n\n*******************************************\n"
	}

	setup := func(layout string, listing string) {
		Expect(os.MkdirAll(filepath.Join(javaHome, layout, "bin"), 0755)).To(Succeed())
		Expect(os.MkdirAll(filepath.Join(javaHome, layout, "lib", "security"), 0755)).To(Succeed())
		Expect(os.WriteFile(filepath.Join(javaHome, layout, "lib", "security", "cacerts"), []byte("store"), 0644)).To(Succeed())
		Expect(os.WriteFile(filepath.Join(javaHome, layout, "bin", "keytool"), []byte(fakeKeytool), 0755)).To(Succeed())
		Expect(os.WriteFile(filepath.Join(javaHome, layout, "listing.txt"), []byte(listing), 0644)).To(Succeed())
	}

	deletedAliases := func(layout string) []string {
		data, err := os.ReadFile(filepath.Join(javaHome, layout, "calls.log"))
		if os.IsNotExist(err) {
			return nil
		}
		Expect(err).NotTo(HaveOccurred())
		return strings.Split(strings.TrimSpace(string(data)), "\n")
	}

	BeforeEach(func() {
		var err error
		javaHome, err = os.MkdirTemp("", "java-home")
		Expect(err).NotTo(HaveOccurred())
		logBuffer = &bytes.Buffer{}
		ctx = &common.Context{Log: libbuildpack.NewLogger(logBuffer)}
	})

	AfterEach(func() {
		os.RemoveAll(javaHome)
		os.Unsetenv("JBP_CONFIG_JRE_REMOVED_ROOTS")
	})

	It("deletes listed roots by fingerprint whatever their alias, and keeps other certificates", func() {
		setup(".", entry("vendor alias with spaces [x]", aaaPEM())+entry("unrelated", unrelatedPEM()))

		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())

		Expect(deletedAliases(".")).To(Equal([]string{"vendor alias with spaces [x]"}))
		Expect(logBuffer.String()).To(ContainSubstring("Removed 1 root certificate(s) from cacerts"))
	})

	It("does nothing when no listed root is present", func() {
		setup(".", entry("unrelated", unrelatedPEM()))

		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())

		Expect(deletedAliases(".")).To(BeEmpty())
		Expect(logBuffer.String()).To(ContainSubstring("already free of the removed root certificates"))
	})

	It("supports the Java 8 JRE layout", func() {
		setup("jre", entry("aaa", aaaPEM()))

		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())

		Expect(deletedAliases("jre")).To(Equal([]string{"aaa"}))
	})

	It("warns and skips when keytool is missing", func() {
		setup(".", entry("aaa", aaaPEM()))
		Expect(os.Remove(filepath.Join(javaHome, "bin", "keytool"))).To(Succeed())

		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())

		Expect(logBuffer.String()).To(ContainSubstring("no keytool found"))
	})

	It("does nothing when the JRE has no cacerts", func() {
		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())
		Expect(logBuffer.String()).NotTo(ContainSubstring("Removed"))
	})

	It("does nothing when disabled", func() {
		setup(".", entry("aaa", aaaPEM()))
		os.Setenv("JBP_CONFIG_JRE_REMOVED_ROOTS", "{enabled: false}")

		Expect(jres.RemoveDistrustedRoots(ctx, javaHome)).To(Succeed())

		Expect(deletedAliases(".")).To(BeEmpty())
	})
})
