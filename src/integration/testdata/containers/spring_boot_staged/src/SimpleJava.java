package io.pivotal;

import com.sun.net.httpserver.HttpServer;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpExchange;
import java.io.IOException;
import java.io.OutputStream;
import java.lang.management.ManagementFactory;
import java.lang.management.RuntimeMXBean;
import java.net.InetSocketAddress;
import java.util.List;

public class SimpleJava {
    public static void main(String[] args) throws IOException {
        // Get port from environment variable or default to 8080
        String portStr = System.getenv("PORT");
        int port = (portStr != null) ? Integer.parseInt(portStr) : 8080;

        // Create HTTP server
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        
        // Add a simple handler for root path
        server.createContext("/", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                String response = "Hello from Spring Boot Application!";
                exchange.sendResponseHeaders(200, response.length());
                OutputStream os = exchange.getResponseBody();
                os.write(response.getBytes());
                os.close();
            }
        });

        // Add handler to expose JVM arguments for testing JAVA_OPTS
        server.createContext("/jvm-args", new HttpHandler() {
            @Override
            public void handle(HttpExchange exchange) throws IOException {
                RuntimeMXBean runtimeMxBean = ManagementFactory.getRuntimeMXBean();
                List<String> jvmArgs = runtimeMxBean.getInputArguments();
                
                StringBuilder response = new StringBuilder();
                response.append("JVM Arguments:\n");
                for (String arg : jvmArgs) {
                    response.append(arg).append("\n");
                }
                
                // Also include JAVA_OPTS environment variable
                String javaOpts = System.getenv("JAVA_OPTS");
                response.append("\nJAVA_OPTS environment variable:\n");
                response.append(javaOpts != null ? javaOpts : "(not set)");
                
                // Include some system properties that are typically set via JAVA_OPTS
                response.append("\n\nRelevant System Properties:\n");
                appendPropertyIfSet(response, "optionKey");
                appendPropertyIfSet(response, "custom.property");
                appendPropertyIfSet(response, "configuredProperty");
                appendPropertyIfSet(response, "userProperty");
                appendPropertyIfSet(response, "java.security.properties");
                appendPropertyIfSet(response, "org.cloudfoundry.security.keymanager.enabled");
                
                String responseStr = response.toString();
                exchange.sendResponseHeaders(200, responseStr.getBytes().length);
                OutputStream os = exchange.getResponseBody();
                os.write(responseStr.getBytes());
                os.close();
            }
            
            private void appendPropertyIfSet(StringBuilder sb, String key) {
                String value = System.getProperty(key);
                if (value != null) {
                    sb.append(key).append("=").append(value).append("\n");
                }
            }
        });

        // Start the server
        server.setExecutor(null); // Use default executor
        server.start();
        System.out.println("Server started on port " + port);
    }
}
