// Package launcher tokenizes JAVA_OPTS and execs the JVM without invoking a
// shell. It exists to remove the runtime `eval "exec java $JAVA_OPTS ..."`
// start command, which lets the shell execute command substitutions and treat
// metacharacters (&, |, ;, newlines) in user-provided JAVA_OPTS as operators.
package javaexec

import "strings"

// TokenizeJavaOpts splits a JAVA_OPTS string into individual arguments using
// POSIX shell word-splitting and quote-removal rules, but WITHOUT performing
// any expansion: variable references ($VAR), command substitutions ($(...) and
// backticks), globbing, and operators (&, |, ;, <, >) are all treated as
// ordinary literal text. This yields the same arguments the previous
// `eval`-based start command produced for normal and quoted inputs, while
// never executing embedded commands.
//
// An empty or whitespace-only input yields no arguments (nil), so the JVM is
// never handed a spurious empty argument.
func TokenizeJavaOpts(s string) []string {
	var tokens []string
	var b strings.Builder
	started := false

	flush := func() {
		if started {
			tokens = append(tokens, b.String())
			b.Reset()
			started = false
		}
	}

	runes := []rune(s)
	for i := 0; i < len(runes); i++ {
		c := runes[i]
		switch c {
		case ' ', '\t', '\n', '\r', '\v', '\f':
			flush()
		case '\'':
			started = true
			// Single quotes: everything literal until the next single quote.
			for i++; i < len(runes) && runes[i] != '\''; i++ {
				b.WriteRune(runes[i])
			}
		case '"':
			started = true
			// Double quotes: literal, except backslash escapes a small set.
			for i++; i < len(runes) && runes[i] != '"'; i++ {
				if runes[i] == '\\' && i+1 < len(runes) {
					next := runes[i+1]
					switch next {
					case '"', '\\', '$', '`':
						b.WriteRune(next)
						i++
						continue
					case '\n':
						// Line continuation: drop backslash and newline.
						i++
						continue
					}
				}
				b.WriteRune(runes[i])
			}
		case '\\':
			started = true
			// Unquoted backslash escapes the next character.
			if i+1 < len(runes) {
				i++
				b.WriteRune(runes[i])
			} else {
				b.WriteRune('\\')
			}
		default:
			started = true
			b.WriteRune(c)
		}
	}
	flush()

	return tokens
}
