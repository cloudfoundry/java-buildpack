#Buildpack Modes

The Java Buildpack has three execution modes:

* Easy Mode: Uses the repository at [http://download.run.pivotal.io][1]. This is the default, and what we recommend anyone to use.
* Expert Mode: Uses a full replica of the repository at [http://download.run.pivotal.io][1] hosted at a different location, possibly a local intranet. This is what we recommend to anyone that dose't want to access the Internet. It’s easy to keep applications secure and up-to-date, but requires the expertise to run a web-server and keep it in sync with [http://download.run.pivotal.io][1].
* Offline Mode: Uses only the packaged internal cache. This is what we recommend if you wanted a single, self-contained artifact. The downside is having to package and keep all your dependencies up to date.

##Creating an Offline Buildpack

From a local copy of [this][6] Git repository run `bundle exec rake clean package OFFLINE=true` to create a zipped copy of the buildpack. Then use the `cf create-buildpack` and `cf update-buildpack` commands to add and update your new buildpack to a Cloud Foundry instance.

##Replicating the Repository

In order to use Expert Mode you will need to make a replica of the repository at [http://download.run.pivotal.io][1], then fork the `java-buildpack` and update the [configuration][4] of `default_repository_root` to point to your copy of the repository.

To make a replica of the repository at [http://download.run.pivotal.io][1], first download the artifacts and `index.yml` files as described [here][3], make them available at a suitable locations on a web server. All the artifacts and `index.yml` files may be downloaded using the [`replicate`][5] script from the [Java Buildpack Dependency Builder][3] repository.

To use the script, issue the following commands from the root directory of a clone of the [Java Buildpack Dependency Builder][3] repository:

```bash
bundle install
bundle exec bin/replicate [--base-uri <BASE-URI> | --host-name <HOST-NAME>] --output <OUTPUT>
```

| Option | Description |
| ------ | ----------- |
| `-b`, `--base-uri <BASE-URI>` | A URI to replace `https://download.run.pivotal.io` with, in `index.yml` files.  This value should be the network location that the repository is replicated to (e.g. `https://internal-repository:8000/dependencies`).  Either this option or `--host-name`, but not both, **must** be specified.
| `-h`, `--host-name <HOST-NAME>` | A host name to replace `download.run.pivotal.io` with, in `index.yml` files.  This value should be the network host that the repository is replicated to (e.g. `internal-repository`).  Either this option or `--base-uri`, but not both, **must** be specified.
| `-o`, `--output <OUTPUT>` | A filesystem location to replicate the repository to.  This option **must** be specified.

To gain a better understanding of the different ways the Java Buildpack can be used you can read this blog post, ['Packaged and Offline Buildpacks'][2].

[1]: http://download.run.pivotal.io/
[2]: http://blog.cloudfoundry.org/2014/04/03/packaged-and-offline-buildpacks/
[3]: https://github.com/cloudfoundry/java-buildpack-dependency-builder
[4]: https://github.com/cloudfoundry/java-buildpack/blob/master/config/repository.yml
[5]: https://github.com/cloudfoundry/java-buildpack-dependency-builder/blob/master/bin/replicate
[6]: https://github.com/cloudfoundry/java-buildpack