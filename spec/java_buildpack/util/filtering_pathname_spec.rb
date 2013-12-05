# Encoding: utf-8
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

require 'application_helper'
require 'diagnostics_helper'
require 'java_buildpack/util'
require 'java_buildpack/util/filtering_pathname'
require 'set'
require 'spec_helper'

describe JavaBuildpack::Util::FilteringPathname do
  include_context 'application_helper'
  include_context 'diagnostics_helper'

  let(:filter_none) { ->(_) { true } }
  let(:filter_all) { ->(_) { false } }
  let(:filter_goodness) { ->(pathname) { pathname.basename != Pathname.new('bad') } }
  let(:filtering_target) { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_goodness) }
  let(:filtered_target) { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_all) }
  let(:immutable_target) { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_goodness) }
  let(:mutable_target) { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_goodness, true) }
  let(:filename_target) { JavaBuildpack::Util::FilteringPathname.new(Pathname.new('/a/b'), filter_goodness, true) }

  before do |example|
    app_dir.rmtree
    app_dir.mkdir
    create_file 'good'
    create_file 'bad'
  end

  it 'delegate to pathnames which exist and are not filtered' do
    filtering_pathname = JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_none)
    expect(filtering_pathname.ftype).to eq('directory')
  end

  it 'delegate to pathnames which do not exist' do
    filtering_pathname = JavaBuildpack::Util::FilteringPathname.new(app_dir + 'no-such-file', filter_none)
    expect { filtering_pathname.ftype }.to raise_error /No such file or directory/
  end

  it 'delegate to pathnames which exist but which are filtered' do
    filtering_pathname = JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_all)
    expect { filtering_pathname.ftype }.to raise_error /No such file or directory/
  end

  it 'should fail to construct if a .nil file exists' do
    FileUtils.touch Pathname.new("#{app_dir}.nil")
    expect { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_all) }.to raise_error /should not exist/
  end

  it 'should fail if a .nil file is created after construction' do
    filtering_pathname = JavaBuildpack::Util::FilteringPathname.new(app_dir + 'test.file', filter_all)
    FileUtils.touch(app_dir + 'test.file.nil')

    expect { filtering_pathname.ftype }.to raise_error /should not exist/
  end

  it 'should fail to construct if a .nil directory exists' do
    FileUtils.mkdir_p Pathname.new("#{app_dir}.nil")
    expect { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_all) }.to raise_error /should not exist/
  end

  it 'should return a missing method' do
    expect { JavaBuildpack::Util::FilteringPathname.new(app_dir, filter_all).method(:chardev?) }.not_to raise_error
  end

  it 'should filter the result of +' do
    expect(filtering_target + 'good').to exist
    expect(filtering_target + 'bad').not_to exist
  end

  it 'should filter the result of join' do
    expect(filtering_target.join 'good').to exist
    expect(filtering_target.join 'bad').not_to exist
  end

  it 'should filter the result of parent', :filter do
    expect((filtering_target + 'good' + 'extra').parent).to exist
    expect((filtering_target + 'bad' + 'extra').parent).not_to exist
  end

  it 'should compare correctly using <=>' do
    expect((filtering_target + 'good') <=> (app_dir + 'good')).to eq(0)
    expect((filtering_target + 'bad') <=> (app_dir + 'bad')).to eq(1)
  end

  it 'should compare correctly using ==' do
    expect((filtering_target + 'good') == (app_dir + 'good')).to be
    expect((filtering_target + 'bad') == (app_dir + 'bad')).not_to be
  end

  it 'should compare correctly using ===' do
    expect((filtering_target + 'good') === (app_dir + 'good')).to be # rubocop:disable CaseEquality
    expect((filtering_target + 'bad') === (app_dir + 'bad')).not_to be # rubocop:disable CaseEquality
  end

  it 'should delegate relative_path_from' do
    expect_any_instance_of(Pathname).to receive(:relative_path_from) { Pathname.new('test1') }
    relative_path = (filtering_target + 'test1').relative_path_from(Pathname.new(app_dir))
    expect(relative_path).to be_an_instance_of(JavaBuildpack::Util::FilteringPathname)
    expect(relative_path).to eq(Pathname.new('test1'))
  end

  it 'should return path when to_s is called when the path is not filtered out' do
    expect(filtering_target.to_s).to eq(app_dir.to_s)
  end

  it 'should return empty string when to_s is called when the path is filtered out' do
    expect(filtered_target.to_s).to eq('')
  end

  it 'should yield a Pathname for each visible result from each_entry' do
    entries = []
    filtering_target.each_entry do |entry|
      entries << entry
    end
    expect(entries.to_set).to eq([Pathname.new('.'), Pathname.new('..'), Pathname.new('good')].to_set)
  end

  it 'should delegate each_line when the file is filtered in' do
    expect_any_instance_of(Pathname).to receive(:each_line).and_yield('test-line')
    expect { |b| (filtering_target + 'good').each_line(&b) }.to yield_successive_args('test-line')
  end

  it 'should raise error from each_line when the file is filtered out' do
    expect { (filtering_target + 'bad').each_line { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'should return each visible entry from entries' do
    expect(filtering_target.entries.to_set).to eq([Pathname.new('.'), Pathname.new('..'), Pathname.new('good')].to_set)
  end

  it 'should delegate opendir when the directory is filtered in' do
    expect_any_instance_of(Pathname).to receive(:opendir).and_yield('test-dir')
    expect { |b| filtering_target.opendir(&b) }.to yield_successive_args('test-dir')
  end

  it 'should raise error from opendir when the file is filtered out' do
    expect { (filtering_target + 'bad').opendir { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'should delegate sysopen when the file is filtered in' do
    expect_any_instance_of(Pathname).to receive(:sysopen).and_yield(999)
    expect { |b| (filtering_target + 'good').sysopen(&b) }.to yield_successive_args(999)
  end

  it 'should raise error from sysopen when the file is filtered out' do
    expect { (filtering_target + 'bad').sysopen { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'should return each child as a filtered pathname from children' do
    expect(filtering_target.children).to eq([app_dir + 'good'])
  end

  it 'should return each child as a pathname from children(false)' do
    expect(filtering_target.children(false)).to eq([Pathname.new('good')])
  end

  it 'should yield each child as a filtered pathname from each_child' do
    expect { |b| filtering_target.each_child(&b) }.to yield_successive_args(app_dir + 'good')
  end

  it 'should yield each child as a pathname from each_child(false)' do
    expect { |b| filtering_target.each_child(false, &b) }.to yield_successive_args(Pathname.new('good'))
  end

  it 'should yield each component of the path from each_filename' do
    expect { |b| filename_target.each_filename(&b) }.to yield_successive_args('a', 'b')
  end

  it 'should yield each element of the path from descend' do
    expect { |b| filename_target.descend(&b) }.to yield_successive_args(Pathname.new('/'), Pathname.new('/a'), Pathname.new('/a/b'))
  end

  it 'should yield each element of the path from ascend' do
    expect { |b| filename_target.ascend(&b) }.to yield_successive_args(Pathname.new('/a/b'), Pathname.new('/a'), Pathname.new('/'))
  end

  # Check mutators.

  it 'should raise error if chmod is called on an immutable instance' do
    expect { immutable_target.chmod(0644) }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if chmod is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:chmod)
    mutable_target.chmod(0644)
  end

  it 'should raise error if chown is called on an immutable instance' do
    expect { immutable_target.chown('test-user', 100) }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if chown is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:chown)
    mutable_target.chown('test-user', 100)
  end

  it 'should raise error if delete is called on an immutable instance' do
    expect { immutable_target.delete }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if delete is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:delete)
    mutable_target.delete
  end

  it 'should raise error if lchmod is called on an immutable instance' do
    expect { immutable_target.lchmod(0644) }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if lchmod is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:lchmod)
    mutable_target.lchmod(0644)
  end

  it 'should raise error if lchown is called on an immutable instance' do
    expect { immutable_target.lchown('test-user', 100) }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if lchown is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:lchown)
    mutable_target.lchown('test-user', 100)
  end

  it 'should raise error if make_link is called on an immutable instance' do
    expect { immutable_target.make_link('test') }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if make_link is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:make_link)
    mutable_target.make_link('test')
  end

  it 'should raise error if make_symlink is called on an immutable instance' do
    expect { immutable_target.make_symlink('test') }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if make_symlink is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:make_symlink)
    mutable_target.make_symlink('test')
  end

  it 'should raise error if mkdir is called on an immutable instance' do
    expect { immutable_target.mkdir('test') }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if mkdir is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:mkdir)
    mutable_target.mkdir('test')
  end

  it 'should raise error if open is called on an immutable instance with a mutating mode' do
    expect { immutable_target.open('w') { |_| } }.to raise_error /FilteringPathname is immutable/
    expect { immutable_target.open('w+') { |_| } }.to raise_error /FilteringPathname is immutable/
    expect { immutable_target.open('a') { |_| } }.to raise_error /FilteringPathname is immutable/
    expect { immutable_target.open('a+') { |_| } }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if open is called on an immutable instance with a non-mutating mode' do
    expect_any_instance_of(Pathname).to receive(:open)
    immutable_target.open('r') { |_| }
  end

  it 'should delegate if open is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:open)
    mutable_target.open('w') { |_| }
  end

  it 'should raise error if rename is called on an immutable instance' do
    expect { immutable_target.rename('test') }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if rename is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:rename)
    mutable_target.rename('test')
  end

  it 'should raise error if rmdir is called on an immutable instance' do
    expect { immutable_target.rmdir }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if rmdir is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:rmdir)
    mutable_target.rmdir
  end

  it 'should raise error if unlink is called on an immutable instance' do
    expect { immutable_target.unlink }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if unlink is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:unlink)
    mutable_target.unlink
  end

  it 'should raise error if untaint is called on an immutable instance' do
    expect { immutable_target.untaint }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if untaint is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:untaint)
    mutable_target.untaint
  end

  it 'should raise error if taint is called on an immutable instance' do
    expect { immutable_target.taint }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if taint is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:taint)
    mutable_target.taint
  end

  it 'should raise error if mkpath is called on an immutable instance' do
    expect { immutable_target.mkpath }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if mkpath is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:mkpath)
    mutable_target.mkpath
  end

  it 'should raise error if rmtree is called on an immutable instance' do
    expect { immutable_target.rmtree }.to raise_error /FilteringPathname is immutable/
  end

  it 'should delegate if rmtree is called on a mutable instance' do
    expect_any_instance_of(Pathname).to receive(:rmtree)
    mutable_target.rmtree
  end

  # Check Pathname class methods fail (in case FilteringPathname is re-implemented to use inheritance)

  it 'should raise error if getwd is used' do
    expect { JavaBuildpack::Util::FilteringPathname.getwd }.to raise_error /undefined method `getwd'/
  end

  it 'should raise error if glob is used' do
    expect { JavaBuildpack::Util::FilteringPathname.glob '' }.to raise_error /undefined method `glob'/
  end

  it 'should raise error if pwd is used' do
    expect { JavaBuildpack::Util::FilteringPathname.pwd }.to raise_error /undefined method `pwd'/
  end

  def create_file(filename)
    file = app_dir + filename
    FileUtils.mkdir_p file.dirname
    FileUtils.touch file

    file
  end

end
