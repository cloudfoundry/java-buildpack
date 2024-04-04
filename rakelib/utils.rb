# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2022 the original author or authors.
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

module Utils
  class VersionUtils
    class << self
      def version_wildcard?(version_pattern)
        version_pattern.include? '+'
      end

      def version(configuration, index)
        matched_version(configuration['version'], index.keys)
      end

      def matched_version(version_pattern, versions)
        JavaBuildpack::Repository::VersionResolver
          .resolve(JavaBuildpack::Util::TokenizedVersion.new(version_pattern), versions)
      end

      def version_matches?(version_pattern, versions)
        !matched_version(version_pattern, versions).nil?
      end

      def openjdk_jre?(configuration)
        configuration['component_id'].end_with?('_jre') && configuration['sub_component_id'].start_with?('jre')
      end

      def tomcat?(configuration)
        configuration['component_id'].end_with?('tomcat') && configuration['sub_component_id'].start_with?('tomcat')
      end

      def java_version_lines(configuration, configurations)
        configuration['version_lines'].each do |v|
          next if version_line_matches?(configuration, v)

          c1 = configuration.clone
          c1['sub_component_id'] = "jre-#{v.split('.')[0]}"
          c1['version'] = v
          configurations << c1
        end
      end

      def tomcat_version_lines(configuration, configurations)
        configuration['version_lines'].each do |v|
          next if version_line_matches?(configuration, v)

          c1 = configuration.clone
          c1['sub_component_id'] = "tomcat-#{v.split('.')[0]}"
          c1['version'] = v
          configurations << c1
        end
      end

      def version_line_matches?(configuration, v)
        return true if v == configuration['version']
        return false if version_wildcard? v

        version_matches?(configuration['version'], [v])
      end
    end
  end
end
