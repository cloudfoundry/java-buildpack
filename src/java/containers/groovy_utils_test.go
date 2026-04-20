package containers_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry/java-buildpack/src/java/containers"
)

// groovyFile writes content to a temp file and returns its path.
// The file is removed when the current spec ends.
func groovyFile(content string) string {
	tmpFile, err := os.CreateTemp("", "test-*.groovy")
	Expect(err).NotTo(HaveOccurred())
	DeferCleanup(os.Remove, tmpFile.Name())
	_, err = tmpFile.WriteString(content)
	Expect(err).NotTo(HaveOccurred())
	Expect(tmpFile.Close()).To(Succeed())
	return tmpFile.Name()
}

var _ = Describe("GroovyUtils", func() {
	var g *containers.GroovyUtils

	BeforeEach(func() {
		g = &containers.GroovyUtils{}
	})

	Describe("HasMainMethod", func() {
		DescribeTable("detecting main method in Groovy files",
			func(content string, expected bool) {
				Expect(g.HasMainMethod(groovyFile(content))).To(Equal(expected))
			},
			Entry("has static void main", `class MyApp {
	static void main(String[] args) {
		println "Hello"
	}
}`, true),
			Entry("has static void main with extra whitespace", `class MyApp {
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

		It("returns false for an unreadable file", func() {
			Expect(g.HasMainMethod("/nonexistent/file.groovy")).To(BeFalse())
		})
	})

	Describe("IsPOGO", func() {
		DescribeTable("detecting Plain Old Groovy Objects",
			func(content string, expected bool) {
				Expect(g.IsPOGO(groovyFile(content))).To(Equal(expected))
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

		It("returns false for an unreadable file", func() {
			Expect(g.IsPOGO("/nonexistent/file.groovy")).To(BeFalse())
		})
	})

	Describe("HasShebang", func() {
		DescribeTable("detecting shebang in Groovy files",
			func(content string, expected bool) {
				Expect(g.HasShebang(groovyFile(content))).To(Equal(expected))
			},
			Entry("has shebang", "#!/usr/bin/env groovy\nprintln 'Hello World'", true),
			Entry("has groovy shebang", "#!/usr/bin/groovy\nprintln 'Hello'", true),
			Entry("no shebang", `class Alpha {
}`, false),
			Entry("shebang not at start", "\n#!/usr/bin/env groovy\nprintln 'Hello'", false),
			Entry("comment mentioning shebang", `// Use #!/usr/bin/env groovy at the top
println 'Hello'`, false),
		)

		It("returns false for an unreadable file", func() {
			Expect(g.HasShebang("/nonexistent/file.groovy")).To(BeFalse())
		})
	})

	Describe("IsBeans", func() {
		DescribeTable("detecting beans-style configuration",
			func(content string, expected bool) {
				Expect(g.IsBeans(groovyFile(content))).To(Equal(expected))
			},
			Entry("has beans block", `beans {
	bean(MyBean)
}`, true),
			Entry("no beans block", `class Alpha {}`, false),
		)
	})
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

	writeFile := func(name, content string) string {
		path := filepath.Join(tmpDir, name)
		Expect(os.WriteFile(path, []byte(content), 0644)).To(Succeed())
		return path
	}

	Context("with various Groovy script types", func() {
		var pogoFile, nonPogoFile, mainMethodFile, shebangFile string

		BeforeEach(func() {
			pogoFile = writeFile("Alpha.groovy", "class Alpha {}")
			nonPogoFile = writeFile("Application.groovy", "println 'Hello World'")
			mainMethodFile = writeFile("Main.groovy", `class Main {
	static void main(String[] args) {
		println "Main"
	}
}`)
			shebangFile = writeFile("Script.groovy", "#!/usr/bin/env groovy\nprintln 'Script'")
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
		It("skips invalid files and selects the valid one", func() {
			invalidFile := writeFile("invalid.groovy", string([]byte{0xff, 0xfe}))
			validFile := writeFile("valid.groovy", "println 'Hello'")

			result, err := containers.FindMainGroovyScript([]string{invalidFile, validFile})
			Expect(err).NotTo(HaveOccurred())
			Expect(result).To(Equal(validFile))
		})
	})
})
