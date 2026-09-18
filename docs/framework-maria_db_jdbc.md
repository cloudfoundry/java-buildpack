# MariaDB JDBC Framework
The MariaDB JDBC Framework causes a JDBC driver JAR to be automatically downloaded and placed on a classpath to work with a bound [MariaDB][] or [MySQL Service][].  This JAR will not be downloaded if the application provides a MariaDB or MySQL JDBC JAR itself.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound MariaDB or MySQL service and NO provided MariaDB or MySQL JDBC jar.
      <ul>
        <li>Existence of a MariaDB service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service whose name, label or tag has <code>mariadb</code> as a substring.</li>
        <li>Existence of a MySQL service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service whose name, label or tag has <code>mysql</code> as a substring.</li>
        <li>Existence of a MariaDB JDBC jar is defined as the application containing a JAR whose name matches <code>mariadb-java-client*.jar</code></li>
        <li>Existence of a MySQL JDBC jar is defined as the application containing a JAR whose name matches <code>mysql-connector-j*.jar</code></li>
      </ul>
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><code>maria-db-jdbc=&lt;version&gt;</code></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## User-Provided Service (Optional)
Users may optionally provide their own MariaDB or MySQL service. A user-provided MariaDB or MySQL service must have a name or tag with `mariadb` or `mysql` in it so that the MariaDB JDBC Framework will automatically download the JDBC driver JAR and place it on the classpath.

## Configuration
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The MariaDB JDBC driver version is managed by the buildpack manifest.

[Configuration and Extension]: ../README.md#configuration-and-extension
[MariaDB]: https://mariadb.com
[MySQL Service]: http://www.mysql.org
