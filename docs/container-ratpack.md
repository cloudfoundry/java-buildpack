# Ratpack Container

## Implementation Note

**Ratpack applications are handled by the [Dist ZIP Container](container-dist_zip.md)** in the Go-based Java Buildpack. There is no separate Ratpack-specific container implementation because Ratpack applications use the standard Gradle `distZip` packaging format.

The Ratpack Container allows [Ratpack][r] applications, packaged `distZip`-style to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td>
    <td>The <tt>lib/ratpack-core-.*.jar</tt> file exists in either the top-level directory or an immediate subdirectory of the application, AND the application has the standard <tt>bin/</tt> and <tt>lib/</tt> directory structure from Gradle's distZip task.</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>Dist ZIP</tt> (Ratpack is detected as a distZip application)</td>
  </tr>
  <tr>
    <td><strong>Container Used</strong></td>
    <td>Dist ZIP Container</td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

The container expects to run the application created by running [`gradle distZip`][d] in an application built with the Ratpack Gradle plugin. The Gradle distZip task creates a standard `bin/` and `lib/` directory structure, which the Dist ZIP container handles automatically.

## How Ratpack Applications Are Deployed

1. **Build**: Run `gradle distZip` in your Ratpack project
2. **Extract**: Extract the generated ZIP file to get the `bin/` and `lib/` directories
3. **Deploy**: Push the extracted contents to Cloud Foundry
4. **Detection**: The buildpack detects the distZip structure and uses the Dist ZIP container
5. **Execution**: The startup script in `bin/` is executed automatically

## Configuration

Ratpack applications use the same configuration as any distZip application. See the [Dist ZIP Container documentation](container-dist_zip.md) for details.

No Ratpack-specific configuration is needed - the framework is detected automatically when `ratpack-core-*.jar` is found in the `lib/` directory.

[d]: http://www.ratpack.io/manual/current/setup.html#using_the_gradle_plugins
[r]: http://www.ratpack.io
