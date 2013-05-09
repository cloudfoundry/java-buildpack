# Cloud Foundry Java Buildpack
# Copyright (c) the original author or authors.
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

Gem::Specification.new do |s|
  s.name        = 'java-buildpack'
  s.version     = '1.0.0.dev'
  s.summary     = 'Cloud Foundry buildpack for running Java applications'
  s.description = 'Buildpack for running Java applications on Cloud Foundry'
  s.authors     = ['Ben Hale']
  s.email       = 'bhale@gopivotal.com'
  s.homepage    = 'https://github.com/cloudfoundry/java-buildpack'
  s.license     = 'Apache-2.0'

  s.files       = %w(LICENSE NOTICE README.md) + Dir['lib/**/*.rb'] + Dir['bin/*']
  s.executables = Dir['bin/*'].map { |f| File.basename f }
  s.test_files  = Dir['spec/**/*_spec.rb']

  s.required_ruby_version = '>= 1.9.3'

  s.add_dependency 'java-buildpack-utils', '~> 1.0'

  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake', '~> 10.0'
  s.add_development_dependency 'redcarpet', '~> 2.2'
  s.add_development_dependency 'rspec', '~> 2.13'
  s.add_development_dependency 'simplecov', '~> 0.7'
  s.add_development_dependency 'yard', '~> 0.8'

end
