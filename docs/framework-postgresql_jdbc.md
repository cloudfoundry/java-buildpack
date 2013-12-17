# PostgreSQL JDBC Framework
The PostgreSQL JDBC Framework causes a JDBC driver JAR to be automatically downloaded and placed on a classpath to work with a bound [PostgreSQL Service][].  This JAR will not be downloaded if the application provides a PostgreSQL JDBC JAR itself.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound PostgreSQL service and no provided PostgreSQL JDBC JAR.
      <ul>
        <li>Existence of a PostgreSQL service is defined as the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>postgres</code> as a substring.</li>
        <li>Existence of a PostgreSQL JDBC JAR is defined as the application containing a JAR who's name matches <tt>postgresql-*.jar</tt></li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>postgresql-jdbc=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own PostgreSQL service. A user-provided PostgreSQL service must have a name or tag with `postgres` in it so that the PostgreSQL JDBC Framework will automatically download the JDBC driver JAR and place it on the classpath.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/postgresql_jdbc.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the PostgreSQL JDBC repository index ([details][repositories]).
| `version` | The version of PostgreSQL JDBC to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/postgresql_jdbc.yml`]: ../config/postgresql_jdbc.yml
[PostgreSQL Service]: http://www.postgresql.org
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/postgresql-jdbc/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
