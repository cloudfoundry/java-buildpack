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

func newMariaDBContext(buildDir, cacheDir, depsDir string) *common.Context {
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

// vcapServices builds a minimal VCAP_SERVICES JSON string for a named service with a uri credential.
func vcapServices(label, name string, tags []string) string {
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
	return `{"` + label + `":[{"name":"` + name + `","label":"` + label + `","tags":` + tagJSON + `,"credentials":{"uri":"mysql://host/db"}}]}`
}

var _ = Describe("MariaDBJDBC", func() {
	var (
		fw       *frameworks.MariaDBJDBCFramework
		buildDir string
		cacheDir string
		depsDir  string
	)

	BeforeEach(func() {
		var err error
		buildDir, err = os.MkdirTemp("", "mariadb-build")
		Expect(err).NotTo(HaveOccurred())
		cacheDir, err = os.MkdirTemp("", "mariadb-cache")
		Expect(err).NotTo(HaveOccurred())
		depsDir, err = os.MkdirTemp("", "mariadb-deps")
		Expect(err).NotTo(HaveOccurred())
		Expect(os.MkdirAll(filepath.Join(depsDir, "0"), 0755)).To(Succeed())

		fw = frameworks.NewMariaDBJDBCFramework(newMariaDBContext(buildDir, cacheDir, depsDir))
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

		Context("with a mysql service bound (by label)", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("mysql", "my-mysql", nil))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with a mariadb service bound (by label)", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("mariadb", "my-mariadb", nil))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with a service tagged 'mysql'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("p.mysql", "my-mysql-svc", []string{"mysql", "relational"}))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with a service tagged 'mariadb'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("user-provided", "my-mariadb-svc", []string{"mariadb"}))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with a service whose name contains 'mysql'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("user-provided", "prod-mysql-db", nil))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with a service whose name contains 'mariadb'", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("user-provided", "prod-mariadb-db", nil))
			})

			It("returns 'maria-db-jdbc'", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(Equal("maria-db-jdbc"))
			})
		})

		Context("with an unrelated service bound", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("postgresql", "my-pg", []string{"relational"}))
			})

			It("returns empty string", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})

		Context("with a mysql service but aws-mysql-jdbc already in lib/", func() {
			BeforeEach(func() {
				os.Setenv("VCAP_SERVICES", vcapServices("mysql", "my-mysql", nil))
				libDir := filepath.Join(buildDir, "lib")
				Expect(os.MkdirAll(libDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(libDir, "aws-mysql-jdbc-1.1.0.jar"), []byte("fake"), 0644)).To(Succeed())
			})

			It("returns empty string (driver already present)", func() {
				name, err := fw.Detect()
				Expect(err).NotTo(HaveOccurred())
				Expect(name).To(BeEmpty())
			})
		})
	})

	Describe("Finalize", func() {
		Context("when the JAR is present in the dep dir", func() {
			BeforeEach(func() {
				mariadbDir := filepath.Join(depsDir, "0", "mariadb_jdbc")
				Expect(os.MkdirAll(mariadbDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(mariadbDir, "mariadb-jdbc-3.3.2.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("writes a profile.d script", func() {
				Expect(fw.Finalize()).To(Succeed())
				Expect(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh")).To(BeAnExistingFile())
			})

			It("profile.d script exports CLASSPATH containing the JAR path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("export CLASSPATH="))
				Expect(string(content)).To(ContainSubstring("mariadb-jdbc-3.3.2.jar"))
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR"))
			})

			It("profile.d script preserves existing CLASSPATH", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("${CLASSPATH:+:$CLASSPATH}"))
			})

			It("runtime path includes the deps index", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("$DEPS_DIR/0/mariadb_jdbc/mariadb-jdbc-3.3.2.jar"))
			})
		})

		Context("when no JAR is present", func() {
			It("returns an error", func() {
				err := fw.Finalize()
				Expect(err).To(HaveOccurred())
				Expect(err.Error()).To(ContainSubstring("jdbc jar not found"))
			})
		})

		Context("with a different JAR version", func() {
			BeforeEach(func() {
				mariadbDir := filepath.Join(depsDir, "0", "mariadb_jdbc")
				Expect(os.MkdirAll(mariadbDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(mariadbDir, "mariadb-jdbc-2.7.9.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("references the correct JAR filename", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).To(ContainSubstring("mariadb-jdbc-2.7.9.jar"))
			})
		})

		Context("runtime path does not embed staging-time absolute path", func() {
			BeforeEach(func() {
				mariadbDir := filepath.Join(depsDir, "0", "mariadb_jdbc")
				Expect(os.MkdirAll(mariadbDir, 0755)).To(Succeed())
				Expect(os.WriteFile(filepath.Join(mariadbDir, "mariadb-jdbc-3.3.2.jar"), []byte("fake jar"), 0644)).To(Succeed())
			})

			It("does not contain the staging depsDir path", func() {
				Expect(fw.Finalize()).To(Succeed())
				content, err := os.ReadFile(filepath.Join(depsDir, "0", "profile.d", "mariadb_jdbc.sh"))
				Expect(err).NotTo(HaveOccurred())
				Expect(string(content)).NotTo(ContainSubstring(depsDir))
			})
		})
	})
})
