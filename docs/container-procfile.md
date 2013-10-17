# Java Procfile Container
The Java Procfile Container runs applications defined in a `Procfile` using [forego (Foreman in Go)](https://github.com/ddollar/forego).

This is useful when running a third party packaged java application that comes packaged in a `jar`
that is intended to be run using a command like: `java -jar the_packaged_app.jar`

Examples would be [jena-fuseki](http://jena.apache.org/documentation/serving_data/) or [elasticsearch](http://www.elasticsearch.org/).

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td><td><tt>Procfile</tt> in root folder</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>java-procfile</tt></td>
  </tr>
</table>

The Procfile container generates a start command similar to:

```
PATH=.java/bin:$PATH JAVA_OPTS="-Djava.io.tmpdir=$TMPDIR -XX:MaxPermSize=13107K -XX:OnOutOfMemoryError=./.buildpack-diagnostics/killjava -Xmx96M -Xss1M" ./.lib/forego start -p $PORT
```

An example `Procfile` would be:

```
fuseki: ./vendor/jena-fuseki-1.0.0/fuseki-server --port=$PORT --file all_data.nt /ds
```

You can set additional environment variables by having a `.env` file alongside the `Procfile` eg:

```
FUSEKI_HOME=vendor/jena-fuseki-1.0.0
FOO=bar
```