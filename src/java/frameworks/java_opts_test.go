package frameworks

import (
	"strings"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("JavaOpts", func() {
	Describe("shellSplit", func() {
		DescribeTable("shell parsing",
			func(input string, expected []string, shouldError bool) {
				result, err := shellSplit(input)
				if shouldError {
					Expect(err).To(HaveOccurred())
				} else {
					Expect(err).NotTo(HaveOccurred())
					Expect(result).To(Equal(expected))
				}
			},
			Entry("simple space-separated", "-Xmx512M -Xms256M", []string{"-Xmx512M", "-Xms256M"}, false),
			Entry("single quoted with spaces", "-DtestJBPConfig1='test test'", []string{"-DtestJBPConfig1=test test"}, false),
			Entry("double quoted with spaces", `-DtestJBPConfig2="test test"`, []string{"-DtestJBPConfig2=test test"}, false),
			Entry("double quoted with env var", `-DtestJBPConfig2="$PATH"`, []string{"-DtestJBPConfig2=$PATH"}, false),
			Entry("mixed quotes and plain", `-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH" -Xmx512M`,
				[]string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH", "-Xmx512M"}, false),
			Entry("empty string", "", nil, false),
			Entry("only spaces", "   ", nil, false),
			Entry("escaped quotes", `test\ with\ spaces`, []string{"test with spaces"}, false),
			Entry("unclosed single quote", "-Dtest='unclosed", nil, true),
			Entry("unclosed double quote", `-Dtest="unclosed`, nil, true),
			Entry("multiple spaces between args", "-Xmx512M    -Xms256M", []string{"-Xmx512M", "-Xms256M"}, false),
			Entry("Ruby buildpack example", "-DtestJBPConfig1='test test' -DtestJBPConfig2=\"$PATH\"",
				[]string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH"}, false),
			Entry("empty single quotes", "-Dtest=''", []string{"-Dtest="}, false),
			Entry("empty double quotes", `-Dtest=""`, []string{"-Dtest="}, false),
			Entry("mixed quote types", "arg1='value with spaces' arg2=plain",
				[]string{"arg1=value with spaces", "arg2=plain"}, false),
		)

		It("should preserve environment variables literally", func() {
			input := `-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH"`
			result, err := shellSplit(input)
			Expect(err).NotTo(HaveOccurred())

			expected := []string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH"}
			Expect(result).To(Equal(expected))
			Expect(result[1]).To(Equal("-DtestJBPConfig2=$PATH"))
		})
	})

	Describe("rubyStyleEscape", func() {
		DescribeTable("Ruby-style escaping",
			func(input, expected string) {
				result := rubyStyleEscape(input)
				Expect(result).To(Equal(expected))
			},
			Entry("simple value no special chars", "-Xmx512M", "-Xmx512M"),
			Entry("value with spaces", "-DtestJBPConfig1=test test", "-DtestJBPConfig1=test\\ test"),
			Entry("value with equals sign", "-Dkey=value", "-Dkey=value"),
			Entry("value with equals sign in value part", "-Dkey=value=something", "-Dkey=value\\=something"),
			Entry("no equals sign", "-Xmx512M", "-Xmx512M"),
			Entry("value with dollar sign", "-Dpath=$PATH", "-Dpath=$PATH"),
			Entry("complex value with multiple spaces", "-Dprop=hello world test", "-Dprop=hello\\ world\\ test"),
			Entry("path with slashes", "/usr/local/bin:/usr/bin", "/usr/local/bin:/usr/bin"),
			Entry("parentheses in value", "-Dtest=(value)", "-Dtest=\\(value\\)"),
			Entry("percent sign in value", "-XX:OnOutOfMemoryError=kill -9 %p", "-XX:OnOutOfMemoryError=kill\\ -9\\ \\%p"),
		)
	})

	Describe("shellSplit and join round-trip", func() {
		DescribeTable("round-trip parsing",
			func(input, expected string) {
				tokens, err := shellSplit(input)
				Expect(err).NotTo(HaveOccurred())

				result := strings.Join(tokens, " ")
				Expect(result).To(Equal(expected))
			},
			Entry("simple values", "-Xmx512M -Xms256M", "-Xmx512M -Xms256M"),
			Entry("values with spaces in quotes",
				`-DtestJBPConfig1='test test' -DtestJBPConfig2="value with spaces"`,
				"-DtestJBPConfig1=test test -DtestJBPConfig2=value with spaces"),
			Entry("user's example from issue",
				`-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH"`,
				"-DtestJBPConfig1=test test -DtestJBPConfig2=$PATH"),
		)
	})
})
