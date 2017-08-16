# Multiple Buildpack Framework
The Multiple Buildpack Framework enables the Java Buildpack to act as the final buildpack in a multiple buildpack deployment.  It reads the contributions of other, earlier buildpacks and incorporates them into its standard staging.

The Java Options Framework contributes arbitrary Java options to the application at runtime.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of buildpack contribution directories (typically <tt>/tmp/&lt;RANDOM&gt;/deps/&lt;INDEX&gt;</tt> containing a <tt>config.yml</tt> file.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>multi-buildpack=&lt;BUILDPACK_NAME&gt;,...</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Multiple Buildpack Integration API
When the Java Buildpack acts as the final buildpack in a multiple buildpack deployment it honors the following core contract integration points.

| Integration Point | Buildpack Usage
| ----------------- | ---------------
| `/bin` | An existing `/bin` directory contributed by a non-final buildpack will be added to the `$PATH` of the application as it executes
| `/lib` | An existing `/lib` directory contributed by a non-final buildpack will be added to the `$LD_LIBRARY_PATH` of the application as it executes

In addition to the core contract, the Java Buildpack defines the following keys in `config.yml` as extension points for contributing to the application.  **All keys are optional, and all paths are absolute.**

| Key | Type | Description
| --- | ---- | -----------
| `additional_libraries` | `[ path ]` | An array of absolute paths to libraries will be added to the application's classpath
| `environment_variables` | `{ string, ( path \| string ) }` | A hash of string keys to absolute path or string values that will be added as environment variables
| `extension_directories` | `[ path ]` | An array of absolute paths to directories containing JRE extensions
| `java_opts.agentpaths` | `[ path ]` | An array of absolute paths to libraries that will be added as agents
| `java_opts.agentpaths_with_props` | `{ path, { string, string } }` | A nested hash with absolute paths keys and hashes of string keys and string values as a value that will be added as agents with properties
| `java_opts.bootclasspath_ps` | `[ path ]` | An array of absolute paths that will be added to the application's bootclasspath
| `java_opts.javaagents` | `[ path ]` | An array of absolute paths that will be added as javaagents
| `java_opts.preformatted_options` | `[ string ]` | An array of strings that will be added as options without modification
| `java_opts.options` | `{ string, ( path \| string ) }` | A hash of string keys to absolute path or string values that will be added as options
| `java_opts.system_properties` | `{ string , ( path \| string ) }` | A hash of string keys to absolute path or string values that will be added as system properties
| `security_providers` | `[ string ]` | An array of strings to be added to list of security providers
