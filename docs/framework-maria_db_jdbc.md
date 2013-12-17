# MariaDB JDBC Framework
The MariaDB JDBC Framework causes a JDBC driver JAR to be automatically downloaded and placed on a classpath to work with a bound [MariaDB][] or [MySQL Service][].  This JAR will not be downloaded if the application provides a MariaDB or MySQL JDBC JAR itself.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound MariaDB or MySQL service and no provided MariaDB or MySQL JDBC JAR.
      <ul>
        <li>Existence of a MariaDB service is defined as the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>mariadb</code> as a substring.</li>
        <li>Existence of a MySQL service is defined as the <a href="http://docs.cloudfoundry.com/docs/using/deploying-apps/environment-variable.html#VCAP_SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>mysql</code> as a substring.</li>
        <li>Existence of a MariaDB JDBC JAR is defined as the application containing a JAR who's name matches <tt>mariadb-java-client*.jar</tt></li>
        <li>Existence of a MySQL JDBC JAR is defined as the application containing a JAR who's name matches <tt>mysql-connector-java*.jar</tt></li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>maria-db-jdbc=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own MariaDB or MySQL service. A user-provided MariaDB or MySQL service must have a name or tag with `mariadb` or `mysql` in it so that the MariaDB JDBC Framework will automatically download the JDBC driver JAR and place it on the classpath.

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/maria_db_jdbc.yml`][] file.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the MariaDB JDBC repository index ([details][repositories]).
| `version` | The version of MariaDB JDBC to use. Candidate versions can be found in [this listing][].

[Configuration and Extension]: ../README.md#Configuration-and-Extension
[`config/maria_db_jdbc.yml`]: ../config/maria_db_jdbc.yml
[MariaDB]: https://mariadb.com
[MySQL Service]: http://www.mysql.org
[repositories]: extending-repositories.md
[this listing]: http://download.pivotal.io.s3.amazonaws.com/mariadb-jdbc/index.yml
[version syntax]: extending-repositories.md#version-syntax-and-ordering
