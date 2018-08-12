# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2019 the original author or authors.
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

require 'fileutils'
require 'yaml'
require 'java_buildpack/component/versioned_dependency_component'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/framework'
require 'net/http'
require 'json'
require 'rubygems'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for using Snyk to test for known vulnerabilities.
    class Snyk < JavaBuildpack::Component::BaseComponent

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        enabled? ? self.class.to_s.dash_case : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      # This is to change the FS
      def compile
        puts "#{'----->'.red.bold} Running #{'snyk test'.blue.bold} "

        manifests = poms
        if manifests.empty?
          puts '       No manifests found'.yellow
          return
        end

        issues = perform_test manifests
        return if issues.empty?

        raise 'Snyk found vulnerabilities' unless dont_break_build?

        puts '       dont_break_build was defined, continuing despite vulnerabilities found'.yellow
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release; end

      private

      FILTER = /snyk/.freeze

      API_TOKEN_CONFIG = 'api_token'
      API_TOKEN_CRED = 'apiToken'
      API_TOKEN_ENV = 'SNYK_TOKEN'

      API_URL_CONFIG = 'api_url'
      API_URL_CRED = 'apiUrl'
      API_URL_ENV = 'SNYK_API'

      ORG_NAME_CONFIG = 'org_name'
      ORG_NAME_CRED = 'orgName'
      ORG_NAME_ENV = 'SNYK_ORG_NAME'

      DONT_BREAK_BUILD_CONFIG = 'dont_break_build'
      DONT_BREAK_BUILD_ENV = 'SNYK_DONT_BREAK_BUILD'

      SEVERITY_THRESHOLD_CONFIG = 'severity_threshold'
      SEVERITY_THRESHOLD_ENV = 'SNYK_SEVERITY_THRESHOLD'

      private_constant  :FILTER, \
                        :API_TOKEN_CONFIG, :API_TOKEN_CRED, :API_TOKEN_ENV, \
                        :API_URL_CONFIG, :API_URL_CRED, :API_URL_ENV, \
                        :ORG_NAME_CONFIG, :ORG_NAME_CRED, :ORG_NAME_ENV, \
                        :DONT_BREAK_BUILD_CONFIG, :DONT_BREAK_BUILD_ENV, \
                        :SEVERITY_THRESHOLD_CONFIG, :SEVERITY_THRESHOLD_ENV

      def api_token
        @configuration[API_TOKEN_CONFIG] || credentials[API_TOKEN_CRED] || @application.environment[API_TOKEN_ENV]
      end

      def api_url
        @configuration[API_URL_CONFIG] || credentials[API_URL_CRED] || @application.environment[API_URL_ENV] || 'https://snyk.io/api'
      end

      def credentials
        svc = @application.services.find_service(FILTER, API_TOKEN_CRED)
        svc ? svc['credentials'] : {}
      end

      def enabled?
        api_token != nil
      end

      def extract_issues(payload)
        issues = []
        issues += payload['vulnerabilities'] if payload.key? 'vulnerabilities'

        if payload.key? 'issues'
          issues += payload['issues']['vulnerabilities'] if payload['issues'].key? 'vulnerabilities'
          issues += payload['issues']['licenses'] if payload['issues'].key? 'licenses'
        end

        issues
      end

      def dont_break_build?
        (@configuration[DONT_BREAK_BUILD_CONFIG] || @application.environment[DONT_BREAK_BUILD_ENV] || 'false')
          .casecmp('true').zero?
      end

      def filesystem_poms
        (@application.root + '**/pom.xml').glob(File::FNM_DOTMATCH).reject(&:directory?).sort.map { |f| File.read(f) }
      end

      def issues(payload)
        scores    = { 'high' => 3, 'medium' => 2, 'low' => 1 }
        threshold = scores[severity_threshold]

        extract_issues(payload)
          .map { |issue| [scores[issue['severity']], issue] }
          .select { |score, _| score >= threshold }
          .sort { |left, right| left[0] - right[0] }
          .map { |_, issue| issue }
      end

      def issue_summary(issue)
        severity = issue['severity']
        summary = "       ✗ #{severity.capitalize} severity vulnerability found in #{issue['package'].underline}"

        if severity == 'high'
          summary.red
        elsif severity == 'medium'
          summary.yellow
        elsif severity == 'low'
          summary.blue
        end
      end

      def jar_poms
        (@application.root + '**/*.jar')
          .glob(File::FNM_DOTMATCH).reject(&:directory?).sort
          .map do |jar|
            `unzip -Z1 #{jar} | grep "pom\.xml"`.split("\n").map do |pom|
              `unzip -p #{jar} #{pom}`
            end
          end
      end

      def org_name
        @configuration[ORG_NAME_CONFIG] || credentials[ORG_NAME_CRED] || @application.environment[ORG_NAME_ENV]
      end

      def poms
        (filesystem_poms + jar_poms).flatten
      end

      def print_report(issues, payload)
        print_header
        print_issues issues
        print_summary issues, payload
      end

      def print_header
        puts ' '
        puts "       Testing #{@application.details['application_name']}...".white.bold
        puts ' '
      end

      def print_issues(issues)
        issues.each do |issue|
          puts issue_summary(issue)
          puts "         Description: #{issue['title']}"
          puts "         Info: #{issue['url'].underline}"
          puts "         Introduced through: #{issue['from'][0]}"
          puts "         From: #{issue['from'].join(' > ')}"
          puts ' '
        end
      end

      def print_summary(issues, payload)
        result =  "      #{'✓' if issues.empty?} Tested #{payload['dependencyCount'] || 0} " \
                  'dependencies for known vulnerabilities, '

        if issues.empty?
          result = (result + 'no vulnerable paths found').green
        else
          unique_count     = issues.map { |issue| issue['id'] }.uniq.length
          vulnerable_paths = issues.map { |issue| issue['from'] }.flatten.length
          result += "found #{unique_count} vulnerabilities, #{vulnerable_paths} vulnerable paths.".bold.red
        end

        puts result
        puts ' '
      end

      def perform_test(poms)
        response = do_request poms
        payload = parse_response response
        issues  = issues payload
        print_report issues, payload
        issues
      end

      def do_request(poms)
        uri       = URI("#{api_url}/v1/test/maven")
        uri.query = URI.encode_www_form(org: org_name) if org_name && !org_name.empty?

        Net::HTTP.start(uri.host, uri.port, read_timeout: 1000, use_ssl: (uri.scheme == 'https')) do |http|
          request                  = Net::HTTP::Post.new(uri)
          request['Content-Type']  = 'application/json'
          request['Authorization'] = "token #{api_token}"
          request.body             = request_body poms

          http.request(request)
        end
      end

      def request_body(poms)
        body                        = { 'encoding' => 'plain', 'files' => { 'target' => { 'contents' => poms[0] } } }
        body['files']['additional'] = poms[1..-1].map { |pom| { 'contents' => pom } } if poms.length > 1
        body.to_json
      end

      def parse_response(response)
        payload = JSON.parse(response.body || '')
        return payload unless payload['code'] || payload['error']

        if payload['message']&.include?('upgrade your plan')
          payload['message'].concat ' (please contact us at support@snyk.io)'
        end
        raise "Api error: #{payload['message'] || payload['error'] || payload['code']}"
      rescue JSON::ParserError
        raise "Unexpected response from api (HTTP #{response.code} #{response.message})"
      end

      def severity_threshold
        (@configuration[SEVERITY_THRESHOLD_CONFIG] || @application.environment[SEVERITY_THRESHOLD_ENV] || 'low')
          .downcase
      end

    end

  end
end
