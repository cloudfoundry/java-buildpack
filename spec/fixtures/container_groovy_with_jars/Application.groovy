/*
 * Copyright 2013-2017 the original author or authors.
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

import java.lang.management.ManagementFactory


class Main {

    static {
        if (System.getenv()['FAIL_INIT'] != null) {
            throw new RuntimeException('$FAIL_INIT caused initialisation to fail')
        }
    }

    static void main(String[] args) {
        if (System.getenv()['FAIL_OOM'] != null) {
            Thread.start {
                println "Provoking OOM..."
                byte[] _ = new byte[Integer.MAX_VALUE]
            }
        }

        def runtimeMxBean = ManagementFactory.getRuntimeMXBean()
        def data = new TreeMap()
        data["Class Path"] = runtimeMxBean.classPath.split(':')
        data["Environment Variables"] = System.getenv()
        data["Input Arguments"] = runtimeMxBean.inputArguments

        map(data, new IndentingPrintStream(System.out))

        println ''
        println "Sleeping for 1 minute..."
        Thread.sleep(60 * 1000)
    }

    def static list(data, out) {
        data.each { value -> out.println value }
    }

    def static map(data, out) {
        data.keySet().each { key ->
            out.println key

            def value = data[key]
            def indented = out.indent()

            if(value instanceof List) {
                list value, indented
            } else if (value.getClass().isArray()) {
                list Arrays.asList(value), indented
            } else if (value instanceof Map) {
                map value, indented
            } else if (value instanceof String) {
                indented.println value
            } else {
                indented.println "Unknown value type '" + value.getClass().simpleName + "'"
            }
        }
    }

    static class IndentingPrintStream {

        def indent

        def out

        IndentingPrintStream(PrintStream out) {
            this(0, out)
        }

        IndentingPrintStream(int indent, PrintStream out) {
            this.indent = indent
            this.out = out
        }

        void println(String s) {
            def sb = new StringBuilder()

            for (int i = 0; i < indent; i++) {
                sb.append '\t'
            }

            sb.append s

            out.println sb.toString()
        }

        IndentingPrintStream indent() {
            return new IndentingPrintStream(indent + 1, out)
        }
    }
}
