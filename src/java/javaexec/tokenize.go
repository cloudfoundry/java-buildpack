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
		case '$':
			started = true
			b.WriteRune(c)
			// Keep $(...) and ${...} as unbreakable units so that spaces inside
			// do not split the enclosing token. Neither is executed; both pass
			// literally to the JVM.
			if i+1 < len(runes) {
				next := runes[i+1]
				var open, close rune
				if next == '(' {
					open, close = '(', ')'
				} else if next == '{' {
					open, close = '{', '}'
				}
				if open != 0 {
					i++
					b.WriteRune(open)
					depth := 1
					for i++; i < len(runes) && depth > 0; i++ {
						ch := runes[i]
						if ch == open {
							depth++
						} else if ch == close {
							depth--
						}
						b.WriteRune(ch)
						if depth == 0 {
							break
						}
					}
				}
			}
		case '`':
			started = true
			b.WriteRune(c)
			// Keep `...` as one unbreakable unit (same reasoning as $(...)).
			for i++; i < len(runes) && runes[i] != '`'; i++ {
				b.WriteRune(runes[i])
			}
			if i < len(runes) {
				b.WriteRune('`') // closing backtick
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
