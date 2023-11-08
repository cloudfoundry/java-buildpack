# Client Certificate Mapper
The Client Certificate Mapper Framework adds a Servlet Filter to applications that will that maps the `X-Forwarded-Client-Cert` to the `javax|jakarta.servlet.request.X509Certificate` Servlet attribute.

The Client Certificate Mapper Framework will download a helper library, [java-buildpack-client-certificate-mapper][library repository], that will enrich Spring Boot applications classpath.

If the app you're deploying is using Spring Boot 2 or earlier, the latest 1.x version (`javax` support) from [the listing][this listing] will be downloaded.

If the app you're deploying is using Spring Boot 3, the latest 2.x version (`jakarta` support) from [the listing][this listing] will be downloaded.
<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Unconditional</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>client-certificate-mapper=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/client_certificate_mapper.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name              | Description
|-------------------| -----------
| `repository_root` | The URL of the Container Customizer repository index ([details][repositories]).
| `version`         | The version of Container Customizer to use. Candidate versions can be found in [this listing][].
| `javax_forced`    | You can force the download of the v1.x version of the [library][library repository] which is based on `javax` naming.

## Servlet Filter
The [Servlet Filter][] added by this framework maps the `X-Forwarded-Client-Cert` to the `javax.servlet.request.X509Certificate` Servlet attribute for each request.  The `X-Forwarded-Client-Cert` header is contributed by the Cloud Foundry Router and contains the any TLS certificate presented by a client for mututal TLS authentication.  This certificate can then be used by any standard Java security framework to establish authentication and authorization for a request.

[`config/client_certificate_mapper.yml`]: ../config/client_certificate_mapper.yml
[Configuration and Extension]: ../README.md#configuration-and-extension
[repositories]: extending-repositories.md
[Servlet Filter]: https://github.com/cloudfoundry/java-buildpack-client-certificate-mapper
[this listing]: http://download.pivotal.io.s3.amazonaws.com/container-security-provider/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
[library repository]: https://github.com:cloudfoundry/java-buildpack-client-certificate-mapper.git
