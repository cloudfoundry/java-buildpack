# PostgreSQL JDBC Framework
The PostgreSQL JDBC Framework causes a JDBC driver JAR to be automatically downloaded and placed on a classpath to work with a bound [PostgreSQL Service][].  This JAR will not be downloaded if the application provides a PostgreSQL JDBC JAR itself.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a single bound PostgreSQL service and no provided PostgreSQL JDBC JAR.
      <ul>
        <li>Existence of a PostgreSQL service is defined as the <a href="http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES"><code>VCAP_SERVICES</code></a> payload containing a service who's name, label or tag has <code>postgres</code> as a substring.</li>
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
For general information on configuring the buildpack, including how to specify configuration values through environment variables, refer to [Configuration and Extension][].

The framework has no user-configurable buildpack options.  The PostgreSQL JDBC driver version is managed by the buildpack manifest.

[Configuration and Extension]: ../README.md#configuration-and-extension
[PostgreSQL Service]: http://www.postgresql.org
