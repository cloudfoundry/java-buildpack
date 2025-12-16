## IBM JRE
IBM JRE provides IBM® SDK, Java™ Technology Edition, Version 8. Unless otherwise configured, the version of Java that will be used is specified in [`config/ibm_jre.yml`][]. See the license section for restrictions that relate to the use of this image. For more information about IBM® SDK, Java™ Technology Edition and API documentation, see the [IBM Knowledge Center][].

### License
Licenses for the products installed within the buildpack:

IBM® SDK, Java™ Technology Edition, Version 8: [International License Agreement for Non-Warranted Programs][].

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The JRE can be configured by modifying the [`config/ibm_jre.yml`][] file in the buildpack fork.  The JRE uses the [`Repository` utility support][repositories] and so, it supports the [version syntax][]  defined there.

To use IBM JRE instead of OpenJDK without forking java-buildpack, set environment variable and restage:

```bash
cf set-env <app_name> JBP_CONFIG_COMPONENTS '{jres: ["JavaBuildpack::Jre::IbmJRE"]}'
cf restage <app_name>
```

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the IBM JRE repository index ([details][repositories]).
| `version` | The version of Java runtime to use.

### TLS Options
It is recommended to use the following Transport Layer Security (TLS) options for IBM JRE version 8 and above:

`cf set-env <app_name> JAVA_OPTS '-Dcom.ibm.jsse2.overrideDefaultTLS=true'`

### Additional Resources

**Note:** The `resources/ibm_jre` directory approach from the Ruby buildpack (2013-2025) is no longer supported. This was a **buildpack-level** feature for teams with forked buildpacks. The Go buildpack does not package the `resources/` directory.

#### Custom CA Certificates

**Recommended approach:** Use [Cloud Foundry Trusted System Certificates](https://docs.cloudfoundry.org/devguide/deploy-apps/trusted-system-certificates.html). This is the standard Cloud Foundry approach and works for all apps. Operators deploy trusted certificates that are automatically available in `/etc/cf-system-certificates` and `/etc/ssl/certs`.

### Memory
The total available memory for the application's container is specified when an application is pushed.The Java buildpack uses this value to control the JRE's use of various regions of memory and logs the JRE memory settings when the application starts or restarts.

Note: If the total available memory is scaled up or down, the Java buildpack will re-calculate the JRE memory settings the next time the application is started.

#### Total Memory
The user can change the container's total memory available to influence the JRE memory settings. Unless the user specifies the heap size Java option (`-Xmx`), increasing or decreasing the total memory available results in the heap size setting increasing or decreasing by a corresponding amount.

#### Memory Calculation
The user can configure the desired heap ratio (`-Xmx`) by changing the `heap_ratio` attribute under `jre` in [`config/ibm_jre.yml`][] and the buildpack calculates the `-Xmx Memory Setting` based on the total memory available.

The container's total memory is logged during `cf push` and `cf scale`, for example:
```
     state     since                    cpu    memory       disk         details
#0   running   2017-04-10 02:20:03 PM   0.0%   896K of 1G   1.3M of 1G
```

[`config/components.yml`]: ../config/components.yml
[`config/ibm_jre.yml`]: ../config/ibm_jre.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[IBM Knowledge Center]: http://www.ibm.com/support/knowledgecenter/SSYKE2/welcome_javasdk_family.html
[International License Agreement for Non-Warranted Programs]: http://www14.software.ibm.com/cgi-bin/weblap/lap.pl?la_formnum=&li_formnum=L-PMAA-A3Z8P2&title=IBM%AE+SDK%2C+Java%99+Technology+Edition%2C+Version+8.0&l=en
