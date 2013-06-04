# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack/utils/value_resolver'

module JavaBuildpack

  # A class encapsulating the Java options (+JAVA_OPTS+) specified by the user.
  class JavaOpts

    # @!attribute [r] heap_size_maximum
    #   @return [String, nil] the fully qualified maximum heap size (e.g. +-Xmx1024M+) specified by the user or +nil+
    #                         if none was specified
    # @!attribute [r] perm_gen_size_maximum
    #   @return [String, nil] the fully qualified maximum perm gen size (e.g. +-XX:MaxPermSize=128M+) specified by the
    #                         user or +nil+ if none was specified
    # @!attribute [r] stack_size
    #   @return [String, nil] the fully qualified stack size (e.g. +-Xss128M+) specified by the user or +nil+ if none
    #                         was specified
    attr_reader :heap_size_maximum, :perm_gen_size_maximum, :stack_size

    # Creates a new instance, passing the application directory used during release.
    #
    # @param [String] app_dir The application to inspect for values specified by the user
    def initialize(app_dir)
      value_resolver = ValueResolver.new(app_dir)
      @heap_size_maximum = resolve_heap_size_maximum value_resolver
      @perm_gen_size_maximum = resolve_perm_gen_size_maximum value_resolver
      @stack_size = resolve_stack_size value_resolver
    end

    # Returns a space delimited +String+ of the Java options specified by the user.
    #
    # @return [String] a space delimited +String+ of the Java options specified by the user
    def to_s
      [
        @heap_size_maximum,
        @perm_gen_size_maximum,
        @stack_size
      ].compact.sort.join(' ')
    end

    private

    ENV_VAR_HEAP_SIZE_MAXIMUM = 'JAVA_RUNTIME_HEAP_SIZE_MAXIMUM'

    ENV_VAR_PERM_GEN_SIZE_MAXIMUM = 'JAVA_RUNTIME_PERM_GEN_SIZE_MAXIMUM'

    ENV_VAR_STACK_SIZE = 'JAVA_RUNTIME_STACK_SIZE'

    SYS_PROP_HEAP_SIZE_MAXIMUM = 'java.runtime.heap.size.maximum'

    SYS_PROP_PERM_GEN_SIZE_MAXIMUM = 'java.runtime.perm.gen.size.maximum'

    SYS_PROP_STACK_SIZE = 'java.runtime.stack.size'

    def resolve_heap_size_maximum(value_resolver)
      heap_size_maximum = value_resolver.resolve(ENV_VAR_HEAP_SIZE_MAXIMUM, SYS_PROP_HEAP_SIZE_MAXIMUM)
      raise "Invalid maximum heap size '#{heap_size_maximum}': embedded whitespace" if heap_size_maximum =~ /\s/
      heap_size_maximum.nil? ? nil : "-Xmx#{heap_size_maximum}"
    end

    def resolve_perm_gen_size_maximum(value_resolver)
      perm_gen_size_maximum = value_resolver.resolve(ENV_VAR_PERM_GEN_SIZE_MAXIMUM, SYS_PROP_PERM_GEN_SIZE_MAXIMUM)
      raise "Invalid maximum PermGen size '#{perm_gen_size_maximum}': embedded whitespace" if perm_gen_size_maximum =~ /\s/
      perm_gen_size_maximum.nil? ? nil : "-XX:MaxPermSize=#{perm_gen_size_maximum}"
    end

    def resolve_stack_size(value_resolver)
      stack_size = value_resolver.resolve(ENV_VAR_STACK_SIZE, SYS_PROP_STACK_SIZE)
      raise "Invalid stack size '#{stack_size}': embedded whitespace" if stack_size =~ /\s/
      stack_size.nil? ? nil : "-Xss#{stack_size}"
    end

  end

end
