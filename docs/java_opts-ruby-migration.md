# Migrating JAVA_OPTS escaping from the Ruby buildpack

The Go rewrite of the Java buildpack changed how `JAVA_OPTS` is assembled and
passed to the JVM. If you are migrating configs written for the Ruby buildpack,
the escaping rules are different.

---

## What changed

| Mechanism | Ruby buildpack | Go buildpack |
|-----------|---------------|-------------|
| Launch | `eval exec java $JAVA_OPTS ...` | `javaexec` (shell-free tokenizer) |
| `$VAR` in opts | expanded by shell at eval | expanded by `profile.d` at container start |
| `$(cmd)` in opts | **executed** by shell | **never executed** (security fix, #1301) |
| `\` handling | eval consumed one level of backslashes | `javaexec` POSIX: `\\`→`\`, `\"` → `"` |
| `*` glob | expanded against filesystem | literal |

---

## Escaping comparison

### Dollar sign before a variable name

Both buildpacks expand `$VAR` references at runtime. No escaping needed or supported.

```bash
# Works the same in both buildpacks
cf set-env my-app JAVA_OPTS '-Dserver.port=$PORT'
```

To prevent expansion, `\$` works in both buildpacks: `\$VAR` delivers the
literal text `$VAR` to the JVM without expanding it.

### Backslash

```bash
# Ruby buildpack: \\\\ in the manifest/env → \\ after eval → \ to JVM
# Go buildpack:   \\ in the manifest/env → \ to JVM (POSIX tokenizer, one level)
```

| Want to deliver to JVM | Ruby buildpack (env) | Go buildpack (env) |
|------------------------|----------------------|--------------------|
| one `\` | `\\\\` | `\\` |
| two `\\` | `\\\\\\\\` | `\\\\` |
| literal `\$PORT` | `\\\\\$PORT` | not supported — `$PORT` expands |

### Cron expressions and glob characters (`*`)

```bash
# Ruby buildpack: must be quoted carefully to survive eval and glob expansion
# Go buildpack:   write literally — * never globs, no eval
cf set-env my-app JAVA_OPTS '-DcronExpr=0 */7 * * *'
```

### Command substitution

```bash
# Ruby buildpack: $(hostname) in JAVA_OPTS was EXECUTED and replaced with output
# Go buildpack:   $(hostname) reaches the JVM as the literal string $(hostname)
#                 This is intentional — executing user-supplied commands is unsafe
```

---

## Quick migration checklist

1. **Remove extra backslashes.** Replace `\\\\` with `\\` — the old pattern
   survived two shell parse layers (eval) which no longer exist.

2. **`\$VAR` still works.** Keep any `\$VAR` escapes you have — they are
   honoured and pass the literal `$VAR` text to the JVM in both buildpacks.

3. **Cron / glob expressions.** Remove any protective quoting that was needed
   to survive `eval` — write the expression directly.

4. **Command substitutions.** If you relied on `$(cmd)` being executed in
   `JAVA_OPTS` (e.g. `$(hostname)`, `$(cat /etc/myconfig)`), that no longer
   works. Compute the value before the app starts and set it as a separate
   environment variable, then reference it via `$MYVAR` in `JAVA_OPTS`.

---

## References

- [Java Options Framework](framework-java_opts.md)
- Issue [#1301](https://github.com/cloudfoundry/java-buildpack/issues/1301) — remove `eval` from start command
