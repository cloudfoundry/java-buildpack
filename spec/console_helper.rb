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
require 'tee'

shared_context 'console_helper' do

  STDOUT.sync
  STDERR.sync

  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  before do |example|
    $stdout = Tee.open(stdout, stdout: nil)
    $stderr = Tee.open(stderr, stdout: nil)

    if example.metadata[:show_output]
      $stdout.add STDOUT
      $stderr.add STDERR
    end
  end

  after do
    $stderr = STDERR
    $stdout = STDOUT
  end

  def capture_output(out, err)
    t_out = Thread.new { copy_stream(out, $stdout) }
    t_err = Thread.new { copy_stream(err, $stderr) }

    t_out.join
    t_err.join
  end

  def copy_stream(source, destination)
    while (buff = source.read(1))
      destination.write(buff)
      destination.flush
    end
  end

end
