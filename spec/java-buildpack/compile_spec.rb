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

require 'spec_helper'

describe JavaBuildpack::Compile do

  before do
    $stdout = StringIO.new
    $stderr = StringIO.new

    @previous_value = ENV['BUILDPACK_CACHE']
    ENV['BUILDPACK_CACHE'] = Dir.tmpdir
  end

  after do
    ENV['BUILDPACK_CACHE'] = @previous_value
  end

  it 'should extract Java' do
    FIXTURE = 'spec/fixtures/java'

    Dir.mktmpdir do |root|
      FileUtils.cp_r "#{FIXTURE}/.", root
      JavaBuildpack::Compile.new(root, Dir.tmpdir).run

      absolute_java_home = File.join(root, JavaBuildpackUtils::Jre::JAVA_HOME, 'bin', 'java')
      expect(File.exists?(absolute_java_home)).to be_true
    end
  end

end
