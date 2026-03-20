package containers_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
)

var _ = Describe("HasMainMethod", func() {
	DescribeTable("detecting main method in Groovy files",
		func(content string, expected bool) {
			tmpFile, err := os.CreateTemp("", "test-*.groovy")
			Expect(err).NotTo(HaveOccurred())
			defer os.Remove(tmpFile.Name())

			_, err = tmpFile.WriteString(content)
			Expect(err).NotTo(HaveOccurred())
			tmpFile.Close()

			result, err := containers.HasMainMethod(tmpFile.Name())
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(expected))
		},
		Entry("has static void main", `class MyApp {
	static void main(String[] args) {
		println "Hello"
	}
}`, true),
		Entry("has static void main with whitespace variations", `class MyApp {
	static  void  main ( String[] args ) {
		println "Hello"
	}
}`, true),
		Entry("no main method", `class Alpha {
}`, false),
		Entry("simple script no main", `println 'Hello World'`, false),
		Entry("instance method not static main", `class Test {
	void main() {
		println "Not static"
	}
}`, false),
	)
})

var _ = Describe("IsPOGO", func() {
	DescribeTable("detecting Plain Old Groovy Objects",
		func(content string, expected bool) {
			tmpFile, err := os.CreateTemp("", "test-*.groovy")
			Expect(err).NotTo(HaveOccurred())
			defer os.Remove(tmpFile.Name())

			_, err = tmpFile.WriteString(content)
			Expect(err).NotTo(HaveOccurred())
			tmpFile.Close()

			result, err := containers.IsPOGO(tmpFile.Name())
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(expected))
		},
		Entry("simple class definition", `class Alpha {
}`, true),
		Entry("class with inheritance", `class MyApp extends BaseApp {
	void run() {}
}`, true),
		Entry("simple script no class", `println 'Hello World'`, false),
		Entry("script with variables no class", `def name = "World"
println "Hello $name"`, false),
		Entry("class keyword in comment", `// This is not a class
println 'Hello'`, false),
		Entry("class keyword in string", `println "This mentions class but isn't one"`, false),
	)
})

var _ = Describe("HasShebang", func() {
	DescribeTable("detecting shebang in Groovy files",
		func(content string, expected bool) {
			tmpFile, err := os.CreateTemp("", "test-*.groovy")
			Expect(err).NotTo(HaveOccurred())
			defer os.Remove(tmpFile.Name())

			_, err = tmpFile.WriteString(content)
			Expect(err).NotTo(HaveOccurred())
			tmpFile.Close()

			result, err := containers.HasShebang(tmpFile.Name())
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(expected))
		},
		Entry("has shebang", `#!/usr/bin/env groovy
println 'Hello World'`, true),
		Entry("has groovy shebang", `#!/usr/bin/groovy
println 'Hello'`, true),
		Entry("no shebang", `class Alpha {
}`, false),
		Entry("shebang not at start", `
#!/usr/bin/env groovy
println 'Hello'`, false),
		Entry("comment mentioning shebang", `// Use #!/usr/bin/env groovy at the top
println 'Hello'`, false),
	)
})

var _ = Describe("FindMainGroovyScript", func() {
	var tmpDir string

	BeforeEach(func() {
		var err error
		tmpDir, err = os.MkdirTemp("", "groovy-test-*")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterEach(func() {
		os.RemoveAll(tmpDir)
	})

	Context("with various Groovy script types", func() {
		var pogoFile, nonPogoFile, mainMethodFile, shebangFile string

		BeforeEach(func() {
			var err error

			pogoFile = filepath.Join(tmpDir, "Alpha.groovy")
			err = os.WriteFile(pogoFile, []byte("class Alpha {}"), 0644)
			Expect(err).NotTo(HaveOccurred())

			nonPogoFile = filepath.Join(tmpDir, "Application.groovy")
			err = os.WriteFile(nonPogoFile, []byte("println 'Hello World'"), 0644)
			Expect(err).NotTo(HaveOccurred())

			mainMethodFile = filepath.Join(tmpDir, "Main.groovy")
			mainContent := `class Main {
	static void main(String[] args) {
		println "Main"
	}
}`
			err = os.WriteFile(mainMethodFile, []byte(mainContent), 0644)
			Expect(err).NotTo(HaveOccurred())

			shebangFile = filepath.Join(tmpDir, "Script.groovy")
			err = os.WriteFile(shebangFile, []byte("#!/usr/bin/env groovy\nprintln 'Script'"), 0644)
			Expect(err).NotTo(HaveOccurred())
		})

		DescribeTable("finding the main Groovy script",
			func(getScripts func() []string, expected func() string) {
				result, err := containers.FindMainGroovyScript(getScripts())
				Expect(err).NotTo(HaveOccurred())
				Expect(result).To(Equal(expected()))
			},
			Entry("single non-POGO script",
				func() []string { return []string{nonPogoFile} },
				func() string { return nonPogoFile }),
			Entry("POGO and non-POGO - selects non-POGO",
				func() []string { return []string{pogoFile, nonPogoFile} },
				func() string { return nonPogoFile }),
			Entry("single file with main method",
				func() []string { return []string{mainMethodFile} },
				func() string { return mainMethodFile }),
			Entry("single file with shebang",
				func() []string { return []string{shebangFile} },
				func() string { return shebangFile }),
			Entry("only POGO - no candidate",
				func() []string { return []string{pogoFile} },
				func() string { return "" }),
			Entry("multiple candidates - returns empty",
				func() []string { return []string{nonPogoFile, shebangFile} },
				func() string { return "" }),
			Entry("empty list",
				func() []string { return []string{} },
				func() string { return "" }),
		)
	})

	Context("with invalid files", func() {
		It("should skip invalid files and select valid ones", func() {
			invalidFile := filepath.Join(tmpDir, "invalid.groovy")
			err := os.WriteFile(invalidFile, []byte{0xff, 0xfe}, 0644)
			Expect(err).NotTo(HaveOccurred())

			validFile := filepath.Join(tmpDir, "valid.groovy")
			err = os.WriteFile(validFile, []byte("println 'Hello'"), 0644)
			Expect(err).NotTo(HaveOccurred())

			scripts := []string{invalidFile, validFile}
			result, err := containers.FindMainGroovyScript(scripts)
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(validFile))
		})
	})
})
