# Embedded web server examples

The Java Buildpack can run applications which provide their own web server or servlet container, provided as JAR files.

## Example

This example uses Jetty as an embedded web server, but should be applicable for other technologies.

```java

public static void main(String[] args) {
  int port = Integer.parseInt(System.getenv("PORT"));
  Server server = new Server(port);
  server.setHandler(new AbstractHandler() {
      @Override
      public void handle(String target, Request baseRequest, HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
          response.setContentType("text/html;charset=utf-8");
          response.setStatus(HttpServletResponse.SC_OK);
          baseRequest.setHandled(true);
          response.getWriter().println("<h1>Hello, world</h1>");
      }
  });
  server.start();
  server.join();
}
```

The important takeaway is to note that the port comes from the environment variable `port`. Other variables are detailed in the [Cloud Foundry developer guide](http://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html). When the application is built as an executable JAR file, it will be treated as a [Java Main](https://github.com/cloudfoundry/java-buildpack/blob/master/docs/example-java_main.md) application.


