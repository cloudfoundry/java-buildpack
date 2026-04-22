package frameworks_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/frameworks"
	"github.com/cloudfoundry/libbuildpack"
)

func newPostgresContext(buildDir, cacheDir, depsDir string) *common.Context {
	logger := libbuildpack.NewLogger(GinkgoWriter)
	manifest := &libbuildpack.Manifest{}
	installer := &libbuildpack.Installer{}
	stager := libbuildpack.NewStager([]string{buildDir, cacheDir, depsDir, "0"}, logger, manifest)
	return &common.Context{
		Stager:    stager,
		Manifest:  manifest,
		Installer: installer,
		Log:       logger,
		Command:   &libbuildpack.Command{},
	}
}

func postgresVCAPServices(label, name string, tags []string) string {
	tagJSON := "[]"
	if len(tags) > 0 {
		tagJSON = `["`
		for i, t := range tags {
			if i > 0 {
				tagJSON += `","`
			}
			tagJSON += t
		}
		tagJSON += `"]`
	}
	return `{"` + label + `":[{"name":"` + name + `","label":"` + label + `","tags":` + tagJSON + `,"credentials":{"uri":"postgres://host/db"}}]}`
}

var _ = Describe("PostgreSQLJDBC", func() {
	var (
		fw       *frameworks.PostgresqlJdbcFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "pg-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "pg-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "pg-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewPostgresqlJdbcFramework(newPostgresContext(buildDir, cacheDir, depsDir))
	})

	AfterEach(func() {
		os.RemoveAll(buildDir)
		os.RemoveAll(cacheDir)
		os.RemoveAll(depsDir)
		os.Unsetenv("VCAP_SERVICES")
	})

	Describe("Detect", func() {
		Context("with no VCAP_SERVICES set", func() {
			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with a postgres service bound by label", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("postgres", "my-postgres", nil))
			})

			It("returns 'PostgreSQL JDBC'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("PostgreSQL JDBC"))
			})
		})

		Context("with a service tagged 'postgres'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("p.postgres", "my-pg-svc", []string{"postgres", "relational"}))
			})

			It("returns 'PostgreSQL JDBC'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("PostgreSQL JDBC"))
			})
		})

		Context("with a service whose name contains 'postgres'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("user-provided", "prod-postgres-db", nil))
			})

			It("returns 'PostgreSQL JDBC'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("PostgreSQL JDBC"))
			})
		})

		Context("with a service whose name contains 'postgresql'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("user-provided", "prod-postgresql-db", nil))
			})

			It("returns 'PostgreSQL JDBC'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("PostgreSQL JDBC"))
			})
		})

		Context("with an unrelated service (MySQL) bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("mysql", "my-mysql", []string{"relational"}))
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with postgres service but driver already in BOOT-INF/lib", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("postgres", "my-postgres", nil))
				libDir := filepath.Join(buildDir, "BOOT-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "postgresql-42.7.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (driver already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with postgres service but driver already in WEB-INF/lib", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("postgres", "my-postgres", nil))
				libDir := filepath.Join(buildDir, "WEB-INF", "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "postgresql-42.6.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (driver already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with postgres service but driver already in lib/", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", postgresVCAPServices("postgres", "my-postgres", nil))
				libDir := filepath.Join(buildDir, "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "postgresql-42.5.4.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (driver already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with invalid VCAP_SERVICES JSON", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", "{invalid json")
			})

			It("returns empty string without error", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("when the JAR is present", func() {
			BeforeEach(func() {
				pgDir := filepath.Join(depsDir, "0", "postgresql_jdbc")
				Expect(os.MkdirAll(pgDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(pgDir, "postgresql-42.7.3.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("writes a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh")).To(BeAnExistingFile())
			})

			It("profile.d script exports CLASSPATH containing the JAR filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("export CLASSPATH="))
				Expect(string(content)).To(ContainSubstring("postgresql-42.7.3.jar"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("runtime path includes the deps index", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/postgresql_jdbc/postgresql-42.7.3.jar"))
			})

			It("profile.d script preserves existing CLASSPATH", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("${CLASSPATH:+:$CLASSPATH}"))
			})

			It("does not embed the staging-time absolute depsDir path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})
		})

		Context("when no JAR is present", func() {
			It("succeeds without writing a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh")).NotTo(BeAnExistingFile())
			})
		})

		Context("with a different JAR version", func() {
			BeforeEach(func() {
				pgDir := filepath.Join(depsDir, "0", "postgresql_jdbc")
				Expect(os.MkdirAll(pgDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(pgDir, "postgresql-42.6.0.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("references the correct JAR filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "postgresql_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("postgresql-42.6.0.jar"))
			})
		})
	})
})
