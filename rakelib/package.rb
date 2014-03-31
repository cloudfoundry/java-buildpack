# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2014 the original author or authors.
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

require 'rakelib/to_b'

module Package

  ARCHITECTURES = %w(x86_64).freeze

  BUILD_DIR = 'build'.freeze

  HASH = `git rev-parse --short HEAD`.chomp.freeze

  OFFLINE = ENV['OFFLINE'].to_b.freeze

  PLATFORMS = %w(centos6 lucid mountainlion precise).freeze

  REMOTE = `git config --get remote.origin.url`.chomp.freeze

  STAGING_DIR = "#{BUILD_DIR}/staging".freeze

  VERSION = (ENV['VERSION'] || HASH).freeze

  PACKAGE_NAME = "#{BUILD_DIR}/java-buildpack#{'-offline' if OFFLINE}-#{VERSION}.zip".freeze

end
