#Buildpack Modes

The Java Buildpack has three execution modes:

* Easy Mode: Uses the repository at [http://download.run.pivotal.io][1]. This does not require any cloning or downloading unless you want to modify the Cloud Foundry provided buildpack. This is the default, and what we recommend anyone to use.
* Expert Mode: Uses a full or partial replica of the repository at [http://download.run.pivotal.io][1] hosted at a different location, possibly a local intranet. The replica must at least include the `index.yml` files that point to the actual artifacts. This is what we recommend to anyone that does not want to access the Internet. It’s easy to keep applications secure and up-to-date, but requires the expertise to run a web-server and keep it in sync with [http://download.run.pivotal.io][1].
* Offline Mode: Uses only the packaged internal cache. This is what we recommend if you wanted a single, self-contained artifact. The downside is having to package and keep all your dependencies up to date.

##Replicating the Repository (Optional)

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

##Creating an Offline Buildpack

You can download a packaged build of the buildpack from either [master-Tarball][7], [master-zip][8], [release-offline][9] [release-tarball][10], [release-zip][11]. An offline buildpack can also be built from a local clone of [this][6] Git repository run `bundle exec rake clean package OFFLINE=true` to create a zipped copy of the buildpack. Then use the `cf create-buildpack` and `cf update-buildpack` commands to add or update your new buildpack to a Cloud Foundry instance.

```
NAME:
   create-buildpack - Create a buildpack

USAGE:
   cf create-buildpack BUILDPACK PATH POSITION [--enable|--disable]

TIP:
   Path should be a zip file, a url to a zip file, or a local directory. Position is an integer, sets priority, and is sorted from lowest to highest.

OPTIONS:
   --enable	Enable the buildpack
   --disable	Disable the buildpack
```

```
NAME:
   update-buildpack - Update a buildpack

USAGE:
   cf update-buildpack BUILDPACK [-p PATH] [-i POSITION] [--enable|--disable] [--lock|--unlock]

OPTIONS:
   -i 		Buildpack position among other buildpacks
   -p 		Path to directory or zip file
   --enable	Enable the buildpack
   --disable	Disable the buildpack
   --lock	Lock the buildpack
   --unlock	Unlock the buildpack
```

To gain a better understanding of the different ways the Java Buildpack can be used you can read this blog post, ['Packaged and Offline Buildpacks'][2].

[1]: http://download.run.pivotal.io/
[2]: http://blog.cloudfoundry.org/2014/04/03/packaged-and-offline-buildpacks/
[3]: https://github.com/cloudfoundry/java-buildpack-dependency-builder
[4]: https://github.com/cloudfoundry/java-buildpack/blob/master/config/repository.yml
[5]: https://github.com/cloudfoundry/java-buildpack-dependency-builder/blob/master/bin/replicate
[6]: https://github.com/cloudfoundry/java-buildpack
[7]: https://github.com/cloudfoundry/java-buildpack/archive/master.tar.gz
[8]: https://github.com/cloudfoundry/java-buildpack/archive/master.zip
[9]: https://github.com/cloudfoundry/java-buildpack/releases/download/v2.4/java-buildpack-offline-v2.4.zip
[10]: https://github.com/cloudfoundry/java-buildpack/archive/v2.4.tar.gz
[11]: https://github.com/cloudfoundry/java-buildpack/archive/v2.4.zip