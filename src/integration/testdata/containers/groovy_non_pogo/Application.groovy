/*
 * Cloud Foundry Java Buildpack
 * Copyright 2013-2020 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@Grab('io.undertow:undertow-core:2.2.24.Final')
import io.undertow.Undertow
import io.undertow.server.HttpHandler
import io.undertow.server.HttpServerExchange
import io.undertow.util.Headers

def port = System.getenv('PORT') ?: '8080'

println "Starting server on port ${port}..."

Undertow.builder()
    .addHttpListener(port.toInteger(), "0.0.0.0")
    .setHandler({ HttpServerExchange exchange ->
        exchange.getResponseHeaders().put(Headers.CONTENT_TYPE, "text/plain")
        exchange.getResponseSender().send("Hello World")
    } as HttpHandler)
    .build()
    .start()

println "Server started on port ${port}"

// Keep the application running
Thread.sleep(Long.MAX_VALUE)
