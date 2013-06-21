# `JAVA_OPTS` Framework
The `JAVA_OPTS` Framework contributes arbitrary Java options to the application at runtime.

| Detection ||
| --- | ---
| **Criteria** | `java_opts` set
| **Tags** | `openjdk-<version>`

## Configuration
The framework can be configured by modifying the [`config/java_opts.yml`][java_opts_yml] file.

[java_opts_yml]: ../config/java_opts.yml

| Name | Description
| ---- | -----------
| `java_opts` | The Java options to use when running the application.  All values are used without modification when invoking the JVM.
