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
require 'java_buildpack/versioned_dependency_component'

module JavaBuildpack

  describe VersionedDependencyComponent do

    let(:versioned_dependency_component) { StubVersionedDependencyComponent.new 'test-name', {} }

    it 'should fail if methods are unimplemented' do
      expect { versioned_dependency_component.compile }.to raise_error
      expect { versioned_dependency_component.release }.to raise_error
      expect { versioned_dependency_component.alpha? }.to raise_error
    end

  end

  class StubVersionedDependencyComponent < VersionedDependencyComponent

    def initialize(component_name, context)
      super(component_name, context)
    end

    alias_method :super_id, :id

    def id(version)
      super_id version
    end

    alias_method :super_supports?, :supports?

    def alpha?
      super_supports?
    end

    def supports?
      false
    end

  end

end
