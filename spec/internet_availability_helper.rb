# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
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

require 'spec_helper'
require 'java_buildpack/util/cache/internet_availability'

shared_context 'internet_availability_helper' do

  # Reset cache and honour example metadata for cache.
  before do |example|
    JavaBuildpack::Util::Cache::InternetAvailability.clear_internet_availability
    JavaBuildpack::Util::Cache::InternetAvailability.store_internet_availability true if example.metadata[:skip_availability_check]
  end

  ############
  # Run test #
  ############

  # Reset cache
  after do
    JavaBuildpack::Util::Cache::InternetAvailability.clear_internet_availability
  end

end
