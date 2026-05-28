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

		// Security: command substitution is NOT executed; passed through literally.
		// Unquoted, the space inside splits it into two literal tokens (correct
		// word-splitting) — neither is executed.
		{"command substitution unquoted", "-Dx=$(echo HACK)", []string{"-Dx=$(echo", "HACK)"}},
		// Quoted, it stays a single literal argument and is never executed.
		{"command substitution quoted", `-Dx="$(echo danger)"`, []string{"-Dx=$(echo danger)"}},
		{"backtick literal", "-Dx=`id`", []string{"-Dx=`id`"}},
		{"dollar var literal", "-Dx=$HOME", []string{"-Dx=$HOME"}},

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
