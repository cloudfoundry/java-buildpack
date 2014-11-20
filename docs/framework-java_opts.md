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
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by creating or modifying the [`config/java_opts.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `from_environment` | Whether to append the value of the `JAVA_OPTS` environment variable to the collection of Java options
| `java_opts` | The Java options to use when running the application. All values are used without modification when invoking the JVM. The options are specified as a single YAML scalar in plain style or enclosed in single or double quotes. 

Any `JAVA_OPTS` from either the config file or environment variables that configure memory options will cause deployment to fail as they're not allowed. Memory options are configured by the buildpack and may not be modified. 

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

Setting any of the allowed memory settings may require a change to the [Memory Weightings]. Where a value is shown it is the default value for that setting. Settings marked as 'manageable' are dynamically writeable through the JDK management interface, JMX.

| Argument| Description
| ------- | -----------
| `-Xmn size` | The size of the heap for the young generation objects, known as the eden region. This could effect the total heap size [Memory Weightings].
| `-XX:MaxDirectMemorySize=64m` | Upper limit on the maximum amount of allocatable direct buffer memory. This could effect the [Memory Weightings].
| `-XX:+UseGCOverheadLimit` | Use a policy that limits the proportion of the VM's time that is spent in GC before an OutOfMemory error is thrown. Performance Options.
| `-XX:HeapDumpPath=./java_pid<pid>.hprof` | Path to directory or filename for heap dump. Manageable.
| `-XX:-HeapDumpOnOutOfMemoryError` | Dump heap to file when java.lang.OutOfMemoryError is thrown. Manageable.
| `-XX:OnError="<cmd args>;<cmd args>"` | Run user-defined commands on fatal error.
| `-XX:OnOutOfMemoryError="<cmd args>;<cmd args>"` | Run user-defined commands when an OutOfMemoryError is first thrown.
| `-XX:+UseLargePages` | Use large page memory. For details, see Java Support for Large Memory Pages. Debugging Options
| `-XX:LargePageSizeInBytes=4m` | Sets the large page size used for the Java heap.
| `-XX:MaxHeapFreeRatio=70` | Maximum percentage of heap free after GC to avoid shrinking.
| `-XX:MaxNewSize=size` | Maximum size of new generation (in bytes). Since 1.4, MaxNewSize is computed as a function of NewRatio. This could effect the total heap size [Memory Weightings].
| `-XX:MinHeapFreeRatio=40` | Minimum percentage of heap free after GC to avoid expansion.
| `-XX:NewRatio=2` | Ratio of old/new generation heap sizes. 2 is equal to approximately 66%.
| `-XX:NewSize=2m` | Default size of new generation heap region (in bytes). This could effect the total heap size [Memory Weightings].
| `-XX:ReservedCodeCacheSize=32m (aka -Xmaxjitcodesize)` - Java 8 Only | Reserved code cache size (in bytes) - maximum code cache size. This could effect the [Memory Weightings].
| `-XX:SurvivorRatio=8` | Ratio of eden/survivor space size. Solaris only.
| `-XX:TargetSurvivorRatio=50` | Desired percentage of survivor space used after scavenge.
| `-XX:ThreadStackSize=512` | Thread Stack Size (in Kbytes). (0 means use default stack size)

[Memory Weightings]: jre-open_jdk_jre.md#memory-weightings
[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/java_opts.yml`]: ../config/java_opts.yml
