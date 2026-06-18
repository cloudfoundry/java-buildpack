# Java Options Framework
The Java Options Framework contributes arbitrary Java options to the application at runtime.


<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td><tt>java_opts</tt> set in the <tt>config/java_opts.yml</tt> file or the <tt>JAVA_OPTS</tt> environment variable set</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>java-opts</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/java_opts.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `from_environment` | Whether to append the value of the `JAVA_OPTS` environment variable to the collection of Java options
| `java_opts` | The Java options to use when running the application. All values are used without modification when invoking the JVM. The options are specified as a single YAML scalar in plain style or enclosed in single or double quotes.

Any `JAVA_OPTS` from either the config file or environment variables will be specified in the start command after any Java Opts added by other frameworks.

## Runtime variable expansion

Java options are assembled at container start by the buildpack's `profile.d` script
(`00_java_opts.sh`), then passed to the JVM by the shell-free `javaexec` launcher.
Because `javaexec` tokenizes `JAVA_OPTS` without invoking a shell, characters such as
`*`, `&`, `;`, `|`, and `>` are treated as literals — they reach the JVM exactly as
written.

### Environment variable references

`$VARNAME` and `${VARNAME}` references in **both** `JAVA_OPTS` (env) and `java_opts`
(config) are expanded at container start against the runtime environment:

```bash
# $PWD, $HOME, $PORT, and any CF-injected variable all work
cf set-env my-application JAVA_OPTS '-Dapp.config=$PWD/config/app.properties'
cf set-env my-application JAVA_OPTS '-Dserver.port=$PORT'
```

```yaml
# config/java_opts.yml
java_opts: '-Xloggc:$PWD/beacon_gc.log -verbose:gc'
```

### Command substitutions are never executed

`$(...)` and backtick command substitutions are **not** executed. A value such as
`-Dinject=$(hostname)` reaches the JVM as the literal string `-Dinject=$(hostname)`.
This is intentional: executing arbitrary commands from a user-supplied option string
would be a security vulnerability.

### Processor count: `$(nproc)`

The one exception is `-XX:ActiveProcessorCount=$(nproc)`, which the buildpack itself
emits for JRE vendors that need it. The profile.d script resolves this single known
token to the actual CPU count before passing the option to the JVM. Any other
`$(...)` expression passes to the JVM literally.

### Special characters and quoting

Characters that were shell-special under the old `eval`-based launcher (`*`, `&`,
`;`, `|`, `>`) are now passed to the JVM as literals — no quoting tricks required.

POSIX quoting in the assembled `JAVA_OPTS` string is respected by `javaexec`'s
tokenizer: a quoted value such as `"-Dfoo=bar baz"` is delivered as the single
argument `-Dfoo=bar baz`.

| Want to pass to JVM | Write in `JAVA_OPTS` / `java_opts` |
|---------------------|-------------------------------------|
| Literal `$PORT` (no expansion) | `\$PORT` |
| Literal `\` backslash | `\\` |
| Literal `\\` two backslashes | `\\\\` |
| Value of `$PORT` at runtime | `$PORT` |
| Cron expression `0 */7 * * *` | `0 */7 * * *` (no quoting needed) |
| Space inside one JVM arg | `"-Dfoo=bar baz"` (quote the arg) |

```bash
# Expand $PORT at runtime
cf set-env my-application JAVA_OPTS '-Dserver.port=$PORT'

# Literal $PORT — not expanded
cf set-env my-application JAVA_OPTS '-Dexample.literal=\$PORT'

# Windows-style path — \\ becomes one backslash
cf set-env my-application JAVA_OPTS '-Dapp.data=C:\\data\\app'

# Cron expression — * is not glob-expanded
cf set-env my-application JAVA_OPTS '-DcronExpr=0 */7 * * *'
```

> **Note:** `$` followed by a digit or non-identifier character (e.g. `$1`, `$.`)
> is left as-is. Undefined variables expand to an empty string.

> **Migrating from the Ruby buildpack?** See
> [Migrating JAVA_OPTS escaping from the Ruby buildpack](java_opts-ruby-migration.md)
> for a comparison of the escaping rules.

## Examples

### Configuration File Example
```yaml
# config/java_opts.yml
---
from_environment: false
java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc
```

### Environment Variable Override Examples

To override the configuration via the `JBP_CONFIG_JAVA_OPTS` environment variable, use YAML flow style (inline YAML) with curly braces:

**Example 1: Using an array of options (recommended)**
```bash
cf set-env my-application JBP_CONFIG_JAVA_OPTS '{ java_opts: ["-Xms256m", "-Xmx1024m", "-XX:+UseG1GC"] }'
```

Or in the application manifest:
```yaml
env:
  JBP_CONFIG_JAVA_OPTS: '{ java_opts: ["-Xms256m", "-Xmx1024m", "-XX:+UseG1GC"] }'
```

**Example 2: Disabling from_environment**
```bash
cf set-env my-application JBP_CONFIG_JAVA_OPTS '{ from_environment: false, java_opts: ["-Xmx512m"] }'
```

**Example 3: Multiple JVM options**
```yaml
env:
  JBP_CONFIG_JAVA_OPTS: '{ from_environment: false, java_opts: ["-Xmx512M", "-Xms256M", "-Xss1M", "-XX:MetaspaceSize=157286K", "-XX:MaxMetaspaceSize=314572K"] }'
```

**Note**: For backward compatibility, a space-separated string is also supported:
```yaml
env:
  JBP_CONFIG_JAVA_OPTS: '{ java_opts: "-Xmx512M -Xms256M" }'
```
However, using an array format is recommended for clarity and to avoid parsing ambiguities.

## Allowed Memory Settings

| Argument| Description
| ------- | -----------
| `-Xms` | Minimum or initial size of heap.
| `-Xss` | Size of each thread's stack. **This could effect the total heap size. [JRE Memory]**
| `-XX:MaxMetaspaceSize` | The maximum size Metaspace can grow to. **This could effect the total heap size. [JRE Memory]**
| `-XX:MaxPermSize` | The maximum size Permgen can grow to.  Only applies to Java 7. **This could effect the total heap size. [JRE Memory]**
| `-Xmn <SIZE>` | Maximum size of young generation, known as the eden region.
| `-XX:+UseGCOverheadLimit` | Use a policy that limits the proportion of the VM's time that is spent in GC before an `java.lang.OutOfMemoryError` error is thrown.
| `-XX:+UseLargePages` | Use large page memory. For details, see [Java Support for Large Memory Pages].
| `-XX:-HeapDumpOnOutOfMemoryError` | Dump heap to file when `java.lang.OutOfMemoryError` is thrown.
| `-XX:HeapDumpPath=<PATH>` | Path to directory or filename for heap dump.
| `-XX:LargePageSizeInBytes=<SIZE>` | Sets the large page size used for the Java heap.
| `-XX:MaxDirectMemorySize=<SIZE>` | Upper limit on the maximum amount of allocatable direct buffer memory. **This could effect the total heap size. [JRE Memory]**
| `-XX:MaxHeapFreeRatio=<RATIO>` | Maximum percentage of heap free after GC to avoid shrinking.
| `-XX:MaxNewSize=<SIZE>` | Maximum size of new generation. Since `1.4`, `MaxNewSize` is computed as a function of `NewRatio`.
| `-XX:MinHeapFreeRatio=<RATIO>` | Minimum percentage of heap free after GC to avoid expansion.
| `-XX:NewRatio=<RATIO>` | Ratio of old/new generation sizes. 2 is equal to approximately 66%.
| `-XX:NewSize=<SIZE>` | Default size of new generation.
| `-XX:OnError="<CMD ARGS>;<CMD ARGS>"` | Run user-defined commands on fatal error.
| `-XX:ReservedCodeCacheSize=<SIZE>` | _Java 8 Only_ Maximum code cache size. Also know as `-Xmaxjitcodesize`. **This could effect the total heap size. [JRE Memory]**
| `-XX:SurvivorRatio=<RATIO>` | Ratio of eden/survivor space. Solaris only.
| `-XX:TargetSurvivorRatio=<RATIO>` | Desired ratio of survivor space used after scavenge.

[`config/java_opts.yml`]: ../config/java_opts.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Support for Large Memory Pages]: http://www.oracle.com/technetwork/java/javase/tech/largememory-jsp-137182.html
[JRE Memory]: jre-open_jdk_jre.md#memory
