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
require 'fileutils'
require 'java_buildpack/application'

module JavaBuildpack

  describe Application do

    it 'should return a child path if it does not exist' do
      Dir.mktmpdir do |root|
        application = Application.new(root)

        expect(application.child('test_file')).to_not be_nil
      end
    end

    it 'should not return a child path if it exists but is not in the initial contents' do
      Dir.mktmpdir do |root|
        application = Application.new(root)

        FileUtils.touch File.join(root, 'test_file')

        expect(application.child('test_file')).to be_nil
      end
    end

    it 'should return a child path if it exists and is in the initial contents' do
      Dir.mktmpdir do |root|
        FileUtils.touch File.join(root, 'test_file')

        application = Application.new(root)

        expect(application.child('test_file')).to_not be_nil
      end
    end

    it 'should only list children that exist initially' do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p File.join(root, '.test_directory')
        FileUtils.mkdir_p File.join(root, 'test_directory')
        FileUtils.touch File.join(root, '.test_file')
        FileUtils.touch File.join(root, 'test_file')

        application = Application.new(root)

        FileUtils.mkdir_p File.join(root, '.ignore_directory')
        FileUtils.mkdir_p File.join(root, 'ignore_directory')
        FileUtils.touch File.join(root, '.ignore_file')
        FileUtils.touch File.join(root, 'ignore_file')

        children = application.children
        expect(children.size).to eq(4)
        expect(children).to include(Pathname.new(File.join(root, '.test_directory')))
        expect(children).to include(Pathname.new(File.join(root, 'test_directory')))
        expect(children).to include(Pathname.new(File.join(root, '.test_file')))
        expect(children).to include(Pathname.new(File.join(root, 'test_file')))
        expect(children).to_not include(Pathname.new(File.join(root, '.ignore_directory')))
        expect(children).to_not include(Pathname.new(File.join(root, 'ignore_directory')))
        expect(children).to_not include(Pathname.new(File.join(root, '.ignore_file')))
        expect(children).to_not include(Pathname.new(File.join(root, 'ignore_file')))
      end
    end

    it 'should return a component directory' do
      Dir.mktmpdir do |root|
        application = Application.new(root)

        expect(application.component_directory('Test-Component').to_s).to eq(File.join root, '.test-component')
      end
    end

    it 'should return the path relative to the application root' do

      Dir.mktmpdir do |root|
        application = Application.new(root)

        expect(application.relative_path_to(Pathname.new(root) + 'test-directory' + 'test-file')).to eq(Pathname.new('test-directory/test-file'))
      end
    end

  end

end
