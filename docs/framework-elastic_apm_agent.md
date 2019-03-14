# Elastic APM Agent Framework

The Elastic APM Agent Framework causes an application to be automatically configured to work with [Elastic APM][]. 

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a cf service named `elasticapm` will cause the detection and instantiation of the `ElasticApmAgent` code in the buildpack. 
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>elastic-apm-agent=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

For more information regarding setup and configuration, please refer to the [Elastic APM with Pivotal Cloud Foundry tutorial][pivotal].

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

### Create a "elasticapm" Service 

`cf update-user-provided-service elasticapm  -p 'server_urls,secret_token,server_timeout'`
Enter your systems specific values into the service VCAP. 

Bind your application to this service:  `cf bind-service ApplicationName elasticapm `

When the application pushes/restages, this service will be detected and automatically bind the variables, jar file into the java apps startup. 

### Static configuration of supported versions 

The framework can be configured by modifying the [`config/elastic_apm_agent.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Elastic APM repository index ([details][repositories]).
| `version` | The version of Elastic APM to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#configuration-and-extension
[`config/elastic_apm_agent.yml`]: ../config/elastic_apm_agent.yml
[Elastic APM]: https://www.elastic.co/guide/en/apm/agent/java/current/index.html
[repositories]: extending-repositories.md
[this listing]: https://raw.githubusercontent.com/elastic/apm-agent-java/master/cloudfoundry/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
