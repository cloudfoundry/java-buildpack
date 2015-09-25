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

Any `JAVA_OPTS` from either the config file or environment variables that configure memory options will cause deployment to fail as they're not allowed. Memory options are configured by the buildpack and may not be modified.

Any `JAVA_OPTS` from either the config file or environment variables will be specified in the start command after any Java Opts added by other frameworks.

## Escaping strings

Java options will have special characters escaped when used in the shell command that starts the Java application but the `$` and `\` characters will not be escaped. This is to allow Java options to include environment variables when the application starts.

```bash
cf set-env my-application JAVA_OPTS '-Dexample.port=$PORT'
```

If an escaped `$` or `\` character is needed in the Java options they will have to be escaped manually. For example, to obtain this output in the start command.

```bash
-Dexample.other=something.\$dollar.\\slash
```

From the command line use;
```bash
cf set-env my-application JAVA_OPTS '-Dexample.other=something.\\\\\$dollar.\\\\\\\slash'
```

From the [`config/java_opts.yml`][] file use;
```yaml
from_environment: true
java_opts: '-Dexample.other=something.\\$dollar.\\\\slash'
```

Finally, from the applications manifest use;
```yaml
  env:
    JAVA_OPTS: '-Dexample.other=something.\\\\\$dollar.\\\\\\\slash'
```

## Example
```yaml
# JAVA_OPTS configuration
---
from_environment: false
java_opts: -Xloggc:$PWD/beacon_gc.log -verbose:gc
```

## Memory Settings

The following `JAVA_OPTS` are restricted and will cause the application to fail deployment.

* `-Xms`
* `-Xmx`
* `-Xss`
* `-XX:MaxMetaspaceSize`
* `-XX:MaxPermSize`
* `-XX:MetaspaceSize`
* `-XX:PermSize`

### Allowed Memory Settings

Setting any of the allowed memory settings may require a change to the [Memory Weightings]. Where a value is shown it is the default value for that setting.

| Argument| Description
| ------- | -----------
| `-Xmn <SIZE>` | Maximum size of young generation, known as the eden region. **This could effect the total heap size [Memory Weightings].**
| `-XX:+UseGCOverheadLimit` | Use a policy that limits the proportion of the VM's time that is spent in GC before an `java.lang.OutOfMemoryError` error is thrown.
| `-XX:+UseLargePages` | Use large page memory. For details, see [Java Support for Large Memory Pages].
| `-XX:-HeapDumpOnOutOfMemoryError` | Dump heap to file when `java.lang.OutOfMemoryError` is thrown.
| `-XX:HeapDumpPath=<PATH>` | Path to directory or filename for heap dump.
| `-XX:LargePageSizeInBytes=<SIZE>` | Sets the large page size used for the Java heap.
| `-XX:MaxDirectMemorySize=<SIZE>` | Upper limit on the maximum amount of allocatable direct buffer memory. **This could effect the [Memory Weightings].**
| `-XX:MaxHeapFreeRatio=<RATIO>` | Maximum percentage of heap free after GC to avoid shrinking.
| `-XX:MaxNewSize=<SIZE>` | Maximum size of new generation. Since `1.4`, `MaxNewSize` is computed as a function of `NewRatio`. **This could effect the total heap size [Memory Weightings].**
| `-XX:MinHeapFreeRatio=<RATIO>` | Minimum percentage of heap free after GC to avoid expansion.
| `-XX:NewRatio=<RATIO>` | Ratio of old/new generation sizes. 2 is equal to approximately 66%.
| `-XX:NewSize=<SIZE>` | Default size of new generation. **This could effect the total heap size [Memory Weightings].**
| `-XX:OnError="<CMD ARGS>;<CMD ARGS>"` | Run user-defined commands on fatal error.
| `-XX:OnOutOfMemoryError="<CMD ARGS>;<CMD ARGS>"` | Run user-defined commands when an `java.lang.OutOfMemoryError` is first thrown.
| `-XX:ReservedCodeCacheSize=<SIZE>` | _Java 8 Only_ Maximum code cache size. Also know as `-Xmaxjitcodesize`. **This could effect the [Memory Weightings].**
| `-XX:SurvivorRatio=<RATIO>` | Ratio of eden/survivor space. Solaris only.
| `-XX:TargetSurvivorRatio=<RATIO>` | Desired ratio of survivor space used after scavenge.
| `-XX:ThreadStackSize=<SIZE>` | Thread stack size. (0 means use default stack size).

[`config/java_opts.yml`]: ../config/java_opts.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[Java Support for Large Memory Pages]: http://www.oracle.com/technetwork/java/javase/tech/largememory-jsp-137182.html
[Memory Weightings]: jre-open_jdk_jre.md#memory-weightings
