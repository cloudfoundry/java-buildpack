# Java Memory Assistant Framework
The Java Memory Assistant is a Java agent (as in `-javaagent`) that creats heap dumps of your application automatically based on preconfigured conditions of memory usage.
The heap dumps created by the Java Memory Assistant can be analyzed using Java memory profilers that support the `.hprof` format (i.e., virtually all profilers).

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td><code>enabled</code> set in the <code>config/java_memory_assistant.yml</code></td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-memory-assistant=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/java_memory_assistant.yml`][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the Java Memory Assistant framework. By default the agent is turned off.
| `agent.heap_dump_folder` | The folder on the container's filesystem where heap dumps are created. Default value: `$PWD`
| `agent.thresholds.<memory_area>` | This configuration allows to define thresholds for every memory area of the JVM. Thresholds can be defined in absolute percentages, e.g., `75%` creates a heap dump at 75% of the selected memory area. It is also possible to specify relative increases and decreases of memory usage: for example, `+5%/2m` will triggera heap dumpo if the particular memory area has increased by `5%` or more over the last two minutes. See below to check which memory areas are supported. Since version `0.3.0`, thresholds can also be specified in terms of absolute values, e.g., `>400MB` (more than 400 MB) or `<=30KB` (30 KB or less); supported memory size units are `KB`, `MB` and `GB`.
| `agent.check_interval` | The interval between checks. Examples: `1s` (once a second), `3m` (every three minutes), `1h` (once every hour). Default: `5s` (check every five seconds).
| `agent.max_frequency` | Maximum amount of heap dumps that the Java Memory Assistant is allowed to create in a given amount of time. Examples: `1/30s` (no more than one heap dump every thirty seconds), `2/3m` (up to two heap dumps every three minutes), `1/2h` (one heap dump every two hours). The time interval is checked every time one heap dump *should* be created (based on the specified thresholds), and compared with the timestamps of the previously created heap dumps to make sure that the maximum frequency is not exceeded. Default: `1/1m` (one heap dump per minute). |
| `agent.log_level` | The log level used by the Java Memory Assistant. Supported values are the same as the Java buildpack's: `DEBUG`, `WARN`, `INFO`, `ERROR` and `FATAL` (the latter is equivalent to `ERROR`). If the `agent.log_level` is not specified, the Java buildpack's log level will be used. |
| `clean_up.max_dump_count` | Maximum amount of heap dumps that can be stored in the filesystem of the container; when the creation of a new heap dump would cause the threshold to be surpassed, the oldest heap dumps are removed from the file system. Default value: `1` |

### Heap Dump Names

The heap dump filenames will be generated according to the following name pattern:

`<INSTANCE-INDEX>-%ts:yyyyMMdd'T'mmssSSSZ%-<INSTANCE-ID[0,8]>.hprof`

The timestamp pattern `%ts:yyyyMMdd'T'mmssSSSZ%` is equivalent to the `%FT%T%z` pattern of [strftime](http://www.cplusplus.com/reference/ctime/strftime/) for [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601).  The default naming convention matches the [`jvmkill`][] naming convention.

### Supported Memory Areas

| Memory Area            | Property Name    |
|------------------------|------------------|
| Heap                   | `heap`             |
| Code Cache             | `code_cache`       |
| Metaspace              | `metaspace`        |
| Compressed Class Space | `compressed_class` |
| Eden                   | `eden`             |
| Survivor               | `survivor`         |
| Old Generation         | `old_gen`          |

The default values can be found in the [`config/java_memory_assistant.yml`][] file.

### Examples

Enable the Java Memory Assistant with its default settings:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true}'
```

Create heap dumps when the old generation memory pool exceeds 800 MB:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, agent: { thresholds : { old_gen : ">800MB" } } }'
```

Create heap dumps when the old generation grows by more than 20% in two minutes:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, agent : { thresholds : { old_gen : +20%/2m } } }'
```

### What are the right thresholds for your application?

Well, it depends.
The way applications behave in terms of memory management is a direct result of how they are implemented.
This is much more then case when the applications are under heavy load.
Thus, there is no "silver bullet" configuration that will serve all applications equally well, and Java Memory Assistant configurations should result from profiling the application under load and then encode the expected memory usage patterns (plus a margin upwards) to detect anomalies.

Nevertheless, a memory area that tends to be particularly interesting to monitor is the so called "old generation" (`old_gen`).
When instantiated, bjects in the Java heap are allocated in an area called `eden`.
As garbage collections occur, objects that are not reclaimed become first "survivors" (and belong to the namesake `survivor` memory area) and then eventually become `old_gen`.
In other words, `old_gen` objects are those that survived multiple garbage collections.
In contrast, `eden` and `survivor` objects are collectively called "young generation".

Application-wide singletons and pooled objects (threads, connections) are examples of "legitimate" `old_gen` candidates.
But memory leaks, by their very nature or surviving multiple garbage collections, end up in `old_gen` too.
Under load that is not too high for the application (and you should find out what it is with load tests and avoid it via rate limiting, e.g., using [route services](https://docs.cloudfoundry.org/services/route-services.html) in front of your application), Java code that allows the JVM to perform efficient memory management tends to have a rather consistent baseline of `old_gen` objects, with most objects being reclaimed as they are still young generation.
That is, when the `old_gen` grows large with respect to the overall heap, this often signifies some sort of memory leak or, at the very least, suboptimal memory management.
Notable exceptions to this rule of thumb are applications that use large local caches.

### Making sure heap dumps can be created

The Java Virtual Machine must create heap dumps on a file.
Unless you are using a `volume service`, it pretty much means that, even if you are uploading the heap dump somewhere else, the heap dump must first land on the ephemeral disk of the container.
Ephemeral disks have quotas and, if all the space is taken by heap dumps (even incomplete ones!), horrible things are bound to happen to your app.

The maximum size of a heap dump depends on the maximum size of the heap of the Java Virtual Machine.
Consider increasing the disk quota of your warden/garden container via the `cf scale <app-name> -k [new size]` using as `new size` to the outcome of the following calculation:

`[max heap size] * [max heap dump count] + 200MB`

The aditional `200MB` is a rule-of-thumb, generous over-approximation of the amount of disk the buildpack and the application therein needs to run.
If your application requires more filesystem than just a few tens of megabytes, you must increase the additional portion of the disk amount calculation accordingly.

### Where to best store heap dumps?

Heap dumps are created by the Java Virtual Machine on a file on the filesystem mounted by the garden container.
Normally, the filesystem of a container is ephemeral.
That is, if your app crashes or it is shut down, the filesystem of its container is gone with it and so are your heap dumps.

To prevent heap dumps from "going down" with the container, you should consider storing them on a `volume service`.

#### Container-mounted volumes

If you are using a filesystem service that mounts persistent volumes to the container, it is enough to name one of the volume services `heap-dump` or tag one volume with `heap-dump`, and the path specified as the `heap_dump_folder` configuration will be resolved against `<mount-point>/<space_name>-<space_id[0,8]>/<application_name>-<application_id[0-8]>`. The default directory convention matches the [`jvmkill`][] directory convention.

[`config/java_memory_assistant.yml`]: ../config/java_memory_assistant.yml
[`jvmkill`]: jre-open_jdk_jre.md#jvmkill
