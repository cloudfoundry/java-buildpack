# Java Memory Assistant Framework
The Java Memory Assistant is a Java agent (as in `-javaagent`) that helps in creating heap dumps of your application automatically based on preconfigured conditions of memory usage.
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

The framework can be configured by modifying the [``config/java_memory_assistant.yml``][] file in the buildpack fork.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the Java Memory Assistant framework.
| `agent.heap_dump_folder` | The folder on the container's filesystem where heap dumps are created. Default value: `$PWD/dumps`
| `agent.thresholds.<memory_area>` | This configuration allows to define thresholds for every memory area of the JVM. Thresholds can be defined in absolute percentages, e.g., `75%` creates a heap dump at 75% of the selected memory area. It is also possible to specify relative increases and decreases of memory usage: for example, `+5%/2m` will triggera heap dumpo if the particular memory area has increased by `5%` or more over the last two minutes. See below to check which memory areas are supported.
| `agent.check_interval` | The interval between checks. Examples: `1s` (once a second), `3m` (every three minutes), `1h` (once every hour).
| `agent.max_frequency` | Maximum amount of heap dumps that the Java Memory Assistant is allowed to create in any given amount of time. Examples: `1/30s` (one every thirty seconds), `2/3m` (two heap dumps every three minutes), `1/2h` (one heap dump every two hours). The time interval is checked every time one heap dump *should* be created, and compared with the timestamps of the previously created heap dumps to make sure that the maximum frequency is not exceeded. |
| `agent.log_level` | The log level used by the Java Memory Assistant. Supported values are the same as the Java buildpack's: `DEBUG`, `WARN`, `INFO`, `ERROR` and `FATAL` (the latter is factually equivalent to `ERROR`). If the `agent.log_level` is not specified, the Java buildpack's log level will be used. |
| `clean_up.max_dump_count` | Maximum amount of heap dumps that can be stored in the filesystem of the container; when the creation of a new heap dump would cause the threshold to be surpassed, the oldest heap dumps are removed from the file system. Default value: `1` |

### Heap Dump Names
The heap dump filenames will be generated according to the following name pattern:

`<SPACE-ID>_<APPLICATION-NAME>_<INSTANCE-INDEX>_%ts:yyyyMMddmmssSS%_<INSTANCE-ID>.hprof`

Since `<SPACE-ID>` and `<INSTANCE-INDEX>` are GUIDs and no one likes files with names over one-hundred characters, only their first 6 characters are used (à la Git). 
The timestamp pattern `%ts:yyyyMMddmmssSS%` will generate a date like `20170102122430123` (to be read as: 2017, January 2nd at 12:24:30.123).

This naming pattern provides meaningful natural sorting with heap dumps from many different applications belonging to different spaces.
Notice that the addition of the `<INSTANCE-ID>` after the timestamp will tell you also if, in between two heap dumps from the instance `0` of a particular application, the container has been restarted (which causes the `<INSTANCE-ID>` to change).
This way, you should not wonder why two apparently consecutive heap dumps seem to be impossibly different from one another, e.g., singletons that are initialized in the previous heap dump have magically disappeared from the second. 

### Supported Memory Areas:

| Memory Area            | Property Name    |
|------------------------|------------------|
| Heap                   | `heap`             |
| Code Cache             | `code_cache`       |
| Metaspace              | `metaspace`        |
| Compressed Class Space | `compressed_class` |
| Eden                   | `eden`             |
| Survivor               | `survivor`         |
| Old Generation         | `old_gen`          |

The default values can be found in the [``config/java_memory_assistant.yml``][] file.

### Examples:

Enable the Java Memory Assistant with its default settings:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true}'
```

Create heap dumps when the heap exceeds a threshold of 75%:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, agent: { thresholds : { heap : 75% } } }'
```

Create heap dumps when the old generation grows by more than 20% in two minutes:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, agent : { thresholds : { old_gen : +20%/2m } } }'
```

### Making sure heap dumps can be created

The Java Virtual Machine must create heap dumps on a file.
Unless you are using a `volume service`, it pretty much means that, even if you are uploading the heap dump somewhere else, the heap dump must first land on the ephemeral disk of the container.
Ephemeral disks have quotas and, if all the space is taken by heap dumps (even incomplete ones!), horrible things are bound to happen to your app.

The maximum size of a heap dump depends on the maximum size of the heap of the Java Virtual Machine.
Consider increasing the disk quota of your warden/garden container via the `cf scale <app-name> -k [new size]` using as `new size` to the outcome of the following calculation:

`[max heap size] * [max heap dump count] + 200MB`

The aditional `200MB` is a rule-of-thumb, generous over-approximation of the amount of disk the buildpack and the application therein needs to run.
If your application requires more filesystem than just a few tens of megabytes, you must increase the additional portion of the disk amount calculation accordingly.

### Where to store heap dumps?

Heap dumps are created by the Java Virtual Machine on a file on the filesystem mounted by the warden/garden container.
Normally, the filesystem of a container is ephemeral.
That is, if your app crashes or it is shut down, the filesystem of its container is gone with it.
And so are your precious heap dumps.

To prevent heap dumps from "going down" with the container, you should consider storing them on a `volume service`

#### Container-mounted volumes

If you are using a filesystem service that mounts persistent volumes to the container, it is enough to name one of the volume services `jbp-dumps` or tag one volume with `jbp-dumps`, and the path specified as the `heap_dump_folder` configuration will be resolved from the mount-point of that volume.