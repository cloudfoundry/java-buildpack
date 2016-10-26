# Java Memory Assistant Framework
The Java Memory Assistant is a Java agent that helps in creating heap dumps of your application automatically when they are needed.
After a heap dump is created by the Java Memory Assistant, you can analize them using, e.g., [Eclipse MAT](http://www.eclipse.org/mat/).

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td><td><code>enabled</code> set in the <code>config/java_memry_assistant.yml</code> or in the <code>JBP_CONFIG_JAVA_MEMORY_ASSISTANT</code> environment variable during deployment.
</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-memory-assistant=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [``config/java_memory_assistant.yml``] file in the buildpack fork or by using the ``JBP_CONFIG_JAVA_MEMORY_ASSISTANT`` environment variable during deployment.

| Name | Description
| ---- | -----------
| `enabled` | Whether to enable the Java Memory Assistant framework.
| `heap_dump_folder` | The folder on the container's filesystem where heap dumps are created. Default value: `[container root]/app`
| `thresholds` | This configuration allows to define thresholds for every memory area of the JVM in percent, e.g., `75%` creates a heap dump at 75% of the selected memory area. See below to check which memory areas are supported.
| `check_interval` | The interval between checks. Examples: `1s` (once a second), `3m` (every three minutes), `1h` (once every hour).
| `max_frequency`| Maximum amount of heap dumps that the Java Memory Assistant is allowed to create in any given amount of time. Examples: `1/30s` (one every thirty seconds), `2/3m` (two heap dumps every three minutes), `1/2h` (one heap dump every two hours). The time interval is checked every time one heap dump *should* be created, and compared with the timestamps of the previously created heap dumps to make sure that the maximum frequency is not exceeded. |
| `max_dump_count` | Maximum amount of heap dumps that can be stored in the filesystem of the container; when the creation of a new heap dump would cause the threshold to be surpassed, the oldest heap dumps are removed from the file system. Default value: `1` |

### Heap Dump Names
The heap dump filenames will be generated according to the following name pattern:

`[space_id]_[application_name]_[instance_index]_%ts:yyyyMMddmmssSS%_[instance_id].hprof`

In the pattern above, `[something]` is to be understood as the value of the `something` property in the [VCAP_APPLICATION environment variable](https://docs.run.pivotal.io/devguide/deploy-apps/environment-variable.html#VCAP-APPLICATION).
Since `space_id` and `instance_id` are GUIDs and no one likes files with names over one-hundred characters, only their first 6 characters are used (à la Git). 
The timestamp pattern `%ts:yyyyMMddmmssSS%` will generate a date like `20170102122430123` (to be read as: 2017, January 2nd at 12:24:30.123).

This naming pattern has been painstakingly engineered to provide meaningful natural sorting for folders with large numbers of heap dumps from many different applications in different spaces (e.g., a very large, organization-wide S3 bucket).
Notice that the addition of the `[instance_id]` after the timestamp will will tell you also if, in between two heap dumps from the instance `0` of a particular application, the container has been restarted (which causes the `instance_id` to change).
This way, you should not wonder why two apparently consecutive heap dumps seem to be impossibly different from one another, e.g., singletons that are initialized in the previous heap dump have magically disappeared from the second. 

###Supported Memory Areas:

| Memory Area            | Property Name    |
|------------------------|------------------|
| Heap                   | `heap`             |
| Code Cache             | `code_cache`       |
| Metaspace              | `metaspace`        |
| Compressed Class Space | `compressed_class` |
| Eden                   | `eden`             |
| Survivor               | `survivor`         |
| Old Generation         | `old_gen`          |

The default values can be found in the [``config/java_memory_assistant.yml``] file.

###Examples:

Enable the Java Memory Assistant with its default settings:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true}'
```

Create heap dumps when the heap exceeds a threshold of 75%:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, thresholds : { heap : 75% } }'
```

Create heap dumps when the old generation grows by more than 20% in two minutes:

```yaml
JBP_CONFIG_JAVA_MEMORY_ASSISTANT: '{enabled : true, thresholds : { old_gen : +20%/2m } }'
```

### Making sure heap dumps can be created

The Java Virtual Machine must create heap dumps on a file.
Unless you are using a `filesystem service` (which does not come out of the box in a Cloud Foundry installation), it pretty much means that, even if you are uploading the heap dump somewhere else, the heap dump must first land on the ephemeral disk of the container.
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
However, there are a few options to make sure that your heap dumps survive the decomissioning of the container.

#### Container-mounted volumes

If you are using a filesystem service that mounts persistent volumes to the container, consider using the `heap_dump_folder` to point to the mount-point of your volume.

#### Amazon S3

Right after having been created on the container's filesystem, heap dumps can be pushed to a bucket hosted by the Amazon S3 service.
To instruct the Java Memory Assistant to push the S3 service, bind a [user-defined service](https://docs.cloudfoundry.org/devguide/services/application-binding.html) named `jma_upload_S3` specifying the following data:

| Name | Description
| ---- | -----------
| `bucket` | (Required) The id of the S3 bucket
| `region` | (Required) The AWS region hosting the bucket
| `key` | (Required) The [access key](http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html) of your Amazon account
| `secret` | (Required) The [secret access key](http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html) of your Amazon account
| `keep_in_container` | (Optional) Whether or not the Java Memory Assistant should keep the heap dump in the container's filesystem after it has been successfully uploaded; the default is `false`, i.e., after successful upload, the heap dump is deleted from the container's filesystem

When the `jma_upload_S3` service is bound, the Java Memory Assistant will use the credentials therein to upload each heap dump after it has been created.

[Configuration and Extension]: ../README.md#configuration-and-extension
[``config/java_memory_assistant.yml``]: ../config/java_memory_assistant.yml
