# Buildpack Modes
The Java Buildpack has three execution modes as described in the blog post, ['Packaged and Offline Buildpacks'][l].

* **Easy Mode:** Uses the repository at `https://java-buildpack.cloudfoundry.org`. This does not require any cloning or downloading unless you want to modify the Cloud Foundry provided buildpack. This is the default, and what we recommend to anyone who asks.
* **Expert Mode:**   Refers to a repository hosted at a different location, possibly on an internal network.  The [structure of the repository][r] is defined as an HTTP-accessible collection of files. The repository root must contain an `index.yml` file that is a mapping of concrete versions to absolute URIs.  This repository can be created manually or [creating a replica](#replicating-the-repository-optional) for the repository at `https://java-buildpack.cloudfoundry.org`.  This is what we would recommend to any customer that didn't want to access the Internet. It's easy to keep applications secure and up-to-date, but requires the expertise to run a web-server and keep it up to date.
* **Offline Mode:** Uses only the packaged internal cache. This is what we recommend if you wanted a single, self-contained artifact. The downside is having to package and keep all your dependencies up to date.


## Easy Mode
The "Easy Mode" buildpack is included in all Cloud Foundry distributions and used by default.  To configure the buildpack, refer to [Configuration and Extension][c].

You can also download specific versions of the buildpack to use with the `create-buildpack`, and `update-buildpack` Cloud Foundry CLI commands.  To find these, navigate to the [Java Buildpack Releases page][v] and download one of the following:

  * `java-buildpack-v<VERSION>.zip`
  * Source Code (zip)

To add the buildpack to an instance of Cloud Foundry, use the `cf create-buildpack java-buildpack java-buildpack-v<VERSION>.zip` command.  For more details refer to the [Cloud Foundry buildpack documentation][b].


## Expert Mode
The "Expert Mode" buildpack is a minor fork of the default Java Buildpack.  For details on configuring the buildpack, refer to [Configuration and Extension][c].  To configure the buildpack to point at an alternate repository, modify the [`config/repository.yml`][y] file to use a different `default_repository_root`.

```yaml
# Repository configuration
---
default_repository_root: https://<ALTERNATE_HOST>
```

Once the buildpack has been modified, it needs to be packaged and uploaded to the Cloud Foundry instance.  In order to package the modified buildpack, refer to [Building Packages][p].  To add the buildpack to an instance of Cloud Foundry, use the `cf create-buildpack java-buildpack java-buildpack-v<VERSION>.zip` command.  For more details refer to the [Cloud Foundry buildpack documentation][b].

### Replicating the Repository _(Optional)_
The easiest way to create a fully populated internal repository is to replicate the one found at `https://java-buildpack.cloudfoundry.org`.  The [Java Buildpack Dependency Builder][d] contains a `replicate` script that automates this process.  To use the script, issue the following commands from the root directory of a clone of this repository:

```bash
$ bundle install
$ bundle exec bin/replicate [--base-uri <BASE-URI> | --host-name <HOST-NAME>] --output <OUTPUT>
```

For details on using the `replicate script` refer to [Replicating Repository][e].


## Offline Mode
The "Offline Mode" buildpack is a self-contained packaging of either the "Easy Mode" or "Expert Mode" buildpacks.

You can download specific versions of the "Offline Mode" buildpack to use with the `create-buildpack` and `update-buildpack` Cloud Foundry CLI commands.  To find these, navigate to the [Java Buildpack Releases page][v] and download one of the `java-buildpack-offline-v<VERSION>.zip` file.   In order to package a modified "Offline Mode" buildpack, refer to [Building Packages][p].  To add the buildpack to an instance of Cloud Foundry, use the `cf create-buildpack java-buildpack java-buildpack-offline-v<VERSION>.zip` command.  For more details refer to the [Cloud Foundry buildpack documentation][b].


[b]: http://docs.pivotal.io/pivotalcf/adminguide/buildpacks.html
[c]: ../README.md#configuration-and-extension
[d]: https://github.com/cloudfoundry/java-buildpack-dependency-builder
[e]: https://github.com/cloudfoundry/java-buildpack-dependency-builder#replicating-repository
[l]: http://blog.cloudfoundry.org/2014/04/03/packaged-and-offline-buildpacks/
[p]: ../README.md#building-packages
[r]: https://github.com/cloudfoundry/java-buildpack/blob/master/docs/extending-repositories.md#repository-structure
[v]: https://github.com/cloudfoundry/java-buildpack/releases
[y]: ../config/repository.yml
