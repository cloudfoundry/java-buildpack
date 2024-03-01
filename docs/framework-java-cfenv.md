# Java CfEnv Framework
The Java CfEnv Framework provides the `java-cfenv` library for Spring Boot 3+ applications. This library sets various Spring Boot properties by parsing CloudFoundry variables such as `VCAP_SERVICES`, allowing Spring Boot's autoconfiguration to kick in. 

This is the recommended replacement for Spring AutoReconfiguration library which is deprecated. See the `java-cfenv` <a href="https://github.com/pivotal-cf/java-cfenv">repostitory</a> for more detail.

It also sets the 'cloud' profile for Spring Boot applications, as the Spring AutoReconfiguration framework did.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a `Spring-Boot-Version: 3.*` manifest entry</td>
    <td>No existing `java-cfenv` library found</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>java-cf-env=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script
