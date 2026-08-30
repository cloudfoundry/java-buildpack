package integration_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/cloudfoundry/switchblade"
	"github.com/sclevine/spec"

	. "github.com/onsi/gomega"
)

// stageFixture assembles an app directory in a temp dir: it copies the checked-in
// fixture named by fixture (skipped when empty) and then creates emptyDirs inside
// the copy. Git cannot store a directory, only files, so fixtures whose behaviour
// depends on a directory being empty -- an empty BOOT-INF/lib, or an entirely
// empty app -- cannot be checked in and are built here instead. Callers must call
// the returned cleanup.
func stageFixture(fixtures, fixture string, emptyDirs ...string) (string, func(), error) {
	dir, err := os.MkdirTemp("", "jbp-container-detection-*")
	if err != nil {
		return "", func() {}, err
	}
	cleanup := func() { os.RemoveAll(dir) }

	if fixture != "" {
		if err := os.CopyFS(dir, os.DirFS(filepath.Join(fixtures, "containers", fixture))); err != nil {
			cleanup()
			return "", func() {}, err
		}
	}

	for _, d := range emptyDirs {
		if err := os.MkdirAll(filepath.Join(dir, filepath.FromSlash(d)), 0o755); err != nil {
			cleanup()
			return "", func() {}, err
		}
	}

	return dir, cleanup, nil
}

func testContainerDetectionErrors(platform switchblade.Platform, fixtures string) func(*testing.T, spec.G, spec.S) {
	return func(t *testing.T, context spec.G, it spec.S) {
		var (
			Expect = NewWithT(t).Expect
			name   string
		)

		it.Before(func() {
			var err error
			name, err = switchblade.RandomName()
			Expect(err).NotTo(HaveOccurred())
		})

		it.After(func() {
			if t.Failed() && name != "" {
				t.Logf("FAILED TEST - App/Container: %s", name)
				t.Logf("   Platform: %s", settings.Platform)
			}
			if name != "" && (!settings.KeepFailedContainers || !t.Failed()) {
				Expect(platform.Delete.Execute(name)).To(Succeed())
			}
		})

		context("when detect itself rejects the application", func() {
			it("fails for empty directory", func() {
				appDir, cleanup, err := stageFixture(fixtures, "")
				Expect(err).NotTo(HaveOccurred())
				defer cleanup()

				// CF CLI rejects a truly empty directory before staging; a placeholder lets the buildpack's detect run.
				Expect(os.WriteFile(filepath.Join(appDir, ".keep"), []byte{}, 0644)).To(Succeed())

				_, logs, err := platform.Deploy.Execute(name, appDir)
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("detected a compatible application"))
			})

			it("fails for non-Java files only", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_text_file"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("detected a compatible application"))
			})
		})

		context("when detect passes but no container matches", func() {
			it("fails for thin jar without Main-Class", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_thin_jar"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})
		})

		context("when app looks like Spring Boot but detection fails", func() {
			it("fails for BOOT-INF present but no Spring Boot markers in MANIFEST.MF", func() {
				appDir, cleanup, err := stageFixture(fixtures,
					"no_container_boot_inf_no_markers", "BOOT-INF/classes", "BOOT-INF/lib")
				Expect(err).NotTo(HaveOccurred())
				defer cleanup()

				_, logs, err := platform.Deploy.Execute(name, appDir)
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})

			it("fails for raw jar with non-spring filename", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_raw_jar"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})
		})

		context("when Spring Boot source or partial build is pushed (most common user error)", func() {
			it("fails for Maven source directory (pom.xml but no compiled artifact)", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_maven_source"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})

			it("fails for compiled classes without fat jar packaging", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_target_classes"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})

			it("fails for thin jar without Main-Class (repackage didn't run)", func() {
				_, logs, err := platform.Deploy.
					Execute(name, filepath.Join(fixtures, "containers", "no_container_thin_jar_extracted"))
				Expect(err).To(HaveOccurred())
				Expect(logs.String()).To(ContainSubstring("No suitable container found"))
			})

			it("detects thin jar with Main-Class as JavaMain (not SpringBoot)", func() {
				_, logs, _ := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "21",
					}).
					Execute(name, filepath.Join(fixtures, "containers", "thin_jar_with_main_class"))
				// Assert on the detection decision, not on deployment success: the
				// fixture carries a stub class file, so the app itself cannot run.
				Expect(logs.String()).To(ContainSubstring("Detected container: Java Main"))
			})
		})

		context("when Spring Boot app is detected but misconfigured", func() {
			it("detects Spring Boot even with empty BOOT-INF/lib", func() {
				appDir, cleanup, err := stageFixture(fixtures,
					"no_container_boot_inf_empty_lib", "BOOT-INF/classes", "BOOT-INF/lib")
				Expect(err).NotTo(HaveOccurred())
				defer cleanup()

				_, logs, _ := platform.Deploy.
					WithEnv(map[string]string{
						"BP_JAVA_VERSION": "21",
					}).
					Execute(name, appDir)
				// Assert on the detection decision, not on deployment success: BOOT-INF/lib
				// is empty, so the app has no Spring Boot runtime to start.
				Expect(logs.String()).To(ContainSubstring("Detected container: Spring Boot"))
			})
		})
	}
}

