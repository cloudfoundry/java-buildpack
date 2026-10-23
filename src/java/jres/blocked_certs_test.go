package jres_test

import (
	"bytes"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/jres"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
	"github.com/cloudfoundry/libbuildpack"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

const vendorFingerprint = "0000000000000000000000000000000000000000000000000000000000000001"

var fingerprintLine = regexp.MustCompile(`^[0-9A-F]{64}$`)

func embeddedFingerprints() []string {
	data, err := resources.GetResource("jre/blocked.certs")
	Expect(err).NotTo(HaveOccurred())
	var fingerprints []string
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "Algorithm=") {
			continue
		}
		fingerprints = append(fingerprints, line)
	}
	return fingerprints
}

var _ = Describe("Blocked certificates", func() {
	var (
		ctx       *common.Context
		javaHome  string
		logBuffer *bytes.Buffer
	)

	writeFile := func(relPath, content string) string {
		path := filepath.Join(javaHome, relPath)
		Expect(os.MkdirAll(filepath.Dir(path), 0755)).To(Succeed())
		Expect(os.WriteFile(path, []byte(content), 0644)).To(Succeed())
		return path
	}

	readFile := func(path string) string {
		data, err := os.ReadFile(path)
		Expect(err).NotTo(HaveOccurred())
		return string(data)
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
		os.Unsetenv("JBP_CONFIG_JRE_BLOCKED_CERTS")
	})

	Describe("embedded list", func() {
		It("uses SHA-256 and contains only unique 64 character hex fingerprints", func() {
			data, err := resources.GetResource("jre/blocked.certs")
			Expect(err).NotTo(HaveOccurred())
			Expect(string(data)).To(MatchRegexp(`(?m)^Algorithm=SHA-256$`))

			fingerprints := embeddedFingerprints()
			Expect(fingerprints).NotTo(BeEmpty())
			seen := map[string]bool{}
			for _, fp := range fingerprints {
				Expect(fp).To(MatchRegexp(fingerprintLine.String()))
				Expect(seen[fp]).To(BeFalse(), "duplicate fingerprint %s", fp)
				seen[fp] = true
			}
		})
	})

	Describe("ApplyBlockedCerts", func() {
		It("adds missing fingerprints to lib/security/blocked.certs and keeps vendor entries", func() {
			existing := embeddedFingerprints()[0]
			path := writeFile("lib/security/blocked.certs",
				"Algorithm=SHA-256\n"+vendorFingerprint+"\n"+existing+"\n")

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			content := readFile(path)
			Expect(content).To(HavePrefix("Algorithm=SHA-256\n" + vendorFingerprint + "\n" + existing + "\n"))
			for _, fp := range embeddedFingerprints() {
				Expect(strings.Count(content, fp)).To(Equal(1), "fingerprint %s", fp)
			}
			Expect(logBuffer.String()).To(ContainSubstring(
				"Added %d certificate(s) to blocked.certs", len(embeddedFingerprints())-1))
		})

		It("is idempotent", func() {
			path := writeFile("lib/security/blocked.certs", "Algorithm=SHA-256\n"+vendorFingerprint+"\n")

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())
			first := readFile(path)
			logBuffer.Reset()

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())
			Expect(readFile(path)).To(Equal(first))
			Expect(logBuffer.String()).NotTo(ContainSubstring("Added"))
			Expect(logBuffer.String()).To(ContainSubstring("blocked.certs already contains all blocked certificates"))
		})

		It("appends through a symlinked file and keeps the link", func() {
			target := writeFile("conf/security/blocked.certs", "Algorithm=SHA-256\n"+vendorFingerprint+"\n")
			Expect(os.Chmod(target, 0600)).To(Succeed())
			link := filepath.Join(javaHome, "lib", "security", "blocked.certs")
			Expect(os.MkdirAll(filepath.Dir(link), 0755)).To(Succeed())
			Expect(os.Symlink(target, link)).To(Succeed())

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			info, err := os.Lstat(link)
			Expect(err).NotTo(HaveOccurred())
			Expect(info.Mode() & os.ModeSymlink).NotTo(BeZero())
			targetInfo, err := os.Stat(target)
			Expect(err).NotTo(HaveOccurred())
			Expect(targetInfo.Mode().Perm()).To(Equal(os.FileMode(0600)))
			Expect(readFile(target)).To(HavePrefix("Algorithm=SHA-256\n" + vendorFingerprint + "\n"))
			Expect(readFile(target)).To(ContainSubstring(embeddedFingerprints()[0]))
		})

		It("handles a file without a trailing newline", func() {
			path := writeFile("lib/security/blocked.certs", "Algorithm=SHA-256\n"+vendorFingerprint)

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			lines := strings.Split(strings.TrimSpace(readFile(path)), "\n")
			Expect(lines).To(HaveLen(2 + len(embeddedFingerprints())))
			Expect(lines[1]).To(Equal(vendorFingerprint))
			for _, line := range lines[2:] {
				Expect(line).To(MatchRegexp(fingerprintLine.String()))
			}
		})

		DescribeTable("supports Java 8 layouts",
			func(relPath string) {
				path := writeFile(relPath, "Algorithm=SHA-256\n")

				Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

				content := readFile(path)
				for _, fp := range embeddedFingerprints() {
					Expect(content).To(ContainSubstring(fp))
				}
			},
			Entry("JDK layout", "jre/lib/security/blacklisted.certs"),
			Entry("JRE layout", "lib/security/blacklisted.certs"),
		)

		It("does nothing when the JRE has no blocked certificates file", func() {
			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			_, err := os.Stat(filepath.Join(javaHome, "lib", "security", "blocked.certs"))
			Expect(os.IsNotExist(err)).To(BeTrue())
		})

		It("leaves the file unchanged when it uses a different algorithm", func() {
			original := "Algorithm=SHA-1\n" + vendorFingerprint + "\n"
			path := writeFile("lib/security/blocked.certs", original)

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			Expect(readFile(path)).To(Equal(original))
			Expect(logBuffer.String()).To(ContainSubstring("SHA-1"))
		})

		It("leaves the file unchanged when disabled", func() {
			os.Setenv("JBP_CONFIG_JRE_BLOCKED_CERTS", "{enabled: false}")
			original := "Algorithm=SHA-256\n" + vendorFingerprint + "\n"
			path := writeFile("lib/security/blocked.certs", original)

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			Expect(readFile(path)).To(Equal(original))
		})

		It("stays enabled and warns when the configuration cannot be parsed", func() {
			os.Setenv("JBP_CONFIG_JRE_BLOCKED_CERTS", "{not valid yaml")
			path := writeFile("lib/security/blocked.certs", "Algorithm=SHA-256\n")

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			Expect(readFile(path)).To(ContainSubstring(embeddedFingerprints()[0]))
			Expect(logBuffer.String()).To(ContainSubstring("JBP_CONFIG_JRE_BLOCKED_CERTS"))
		})

		It("updates a read-only file and restores its mode", func() {
			path := writeFile("lib/security/blocked.certs", "Algorithm=SHA-256\n"+vendorFingerprint+"\n")
			Expect(os.Chmod(path, 0444)).To(Succeed())

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			Expect(readFile(path)).To(ContainSubstring(embeddedFingerprints()[0]))
			info, err := os.Stat(path)
			Expect(err).NotTo(HaveOccurred())
			Expect(info.Mode().Perm()).To(Equal(os.FileMode(0444)))
		})

		DescribeTable("accepts the algorithm header as java.util.Properties reads it",
			func(header string) {
				path := writeFile("lib/security/blocked.certs", header+"\n"+vendorFingerprint+"\n")

				Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

				Expect(readFile(path)).To(HavePrefix(header + "\n" + vendorFingerprint + "\n"))
				Expect(readFile(path)).To(ContainSubstring(embeddedFingerprints()[0]))
			},
			Entry("lowercase value", "Algorithm=sha-256"),
			Entry("spaces around separator", "Algorithm = SHA-256"),
			Entry("colon separator", "Algorithm:SHA-256"),
		)

		It("stays enabled when the configuration sets enabled: true", func() {
			os.Setenv("JBP_CONFIG_JRE_BLOCKED_CERTS", "{enabled: true}")
			path := writeFile("lib/security/blocked.certs", "Algorithm=SHA-256\n")

			Expect(jres.ApplyBlockedCerts(ctx, javaHome)).To(Succeed())

			Expect(readFile(path)).To(ContainSubstring(embeddedFingerprints()[0]))
		})
	})
})
