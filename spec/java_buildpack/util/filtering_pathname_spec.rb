# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013-2016 the original author or authors.
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
require 'fileutils'
require 'java_buildpack/util/filtering_pathname'
require 'set'
require 'spec_helper'

describe JavaBuildpack::Util::FilteringPathname do
  include_context 'application_helper'

  let(:filter_none) { ->(_) { true } }
  let(:filter_all) { ->(_) { false } }
  let(:filter_goodness) { ->(pathname) { pathname.basename != Pathname.new('bad') } }
  let(:filter_strict) { ->(pathname) { pathname.basename == Pathname.new('good') } }
  let(:filtering_target) { described_class.new(app_dir, filter_goodness, false) }
  let(:strict_filtering_target) { described_class.new(app_dir, filter_strict, false) }
  let(:filtered_target) { described_class.new(app_dir, filter_all, false) }
  let(:immutable_target) { described_class.new(app_dir, filter_goodness, false) }
  let(:mutable_target) { described_class.new(app_dir, filter_goodness, true) }
  let(:filename_target) { described_class.new(Pathname.new('/a/b'), filter_goodness, true) }

  before do
    create_file 'good'
    create_file 'bad'
  end

  it 'delegates to pathnames which exist and are not filtered' do
    filtering_pathname = described_class.new(app_dir, filter_none, false)
    expect(filtering_pathname.ftype).to eq('directory')
  end

  it 'delegates to pathnames which do not exist' do
    filtering_pathname = described_class.new(app_dir + 'no-such-file', filter_none, false)
    expect { filtering_pathname.ftype }.to raise_error(/No such file or directory/)
  end

  it 'delegates to pathnames which exist but which are filtered' do
    filtering_pathname = described_class.new(app_dir, filter_all, false)
    expect { filtering_pathname.ftype }.to raise_error(/No such file or directory/)
  end

  it 'fails to construct if a .nil file exists' do
    FileUtils.touch Pathname.new("#{app_dir}.nil")
    expect { described_class.new(app_dir, filter_all, false) }.to raise_error(/should not exist/)
  end

  it 'fails if a .nil file is created after construction' do
    filtering_pathname = described_class.new(app_dir + 'test.file', filter_all, false)
    FileUtils.touch(app_dir + 'test.file.nil')

    expect { filtering_pathname.ftype }.to raise_error(/should not exist/)
  end

  it 'fails to construct if a .nil directory exists' do
    FileUtils.mkdir_p Pathname.new("#{app_dir}.nil")
    expect { described_class.new(app_dir, filter_all, false) }.to raise_error(/should not exist/)
  end

  it 'returns a missing method' do
    expect { described_class.new(app_dir, filter_all, false).method(:chardev?) }.not_to raise_error
  end

  it 'filters the result of +' do
    expect(filtering_target + 'good').to exist
    expect(filtering_target + 'bad').not_to exist
  end

  it 'stringifies non-clean paths' do
    expect(described_class.new(Pathname.new('/a/b/..'), filter_none, false).to_s).to eq('/a/b/..')
  end

  it 'produces result for + with a non-clean path' do
    base = described_class.new(Pathname.new('/a'), filter_none, false)
    expect((base + 'b/..').to_s).to eq('/a/b/..')
  end

  it 'produces result for + with a non-clean path starting with '..'' do
    base = described_class.new(Pathname.new('/a/b'), filter_none, false)
    expect((base + '..').to_s).to eq('/a')
  end

  it 'filters the result of join' do
    expect(filtering_target.join('good')).to exist
    expect(filtering_target.join('bad')).not_to exist
  end

  it 'filters the result of parent', :filter do
    expect((filtering_target + 'good' + 'extra').parent).to exist
    expect((filtering_target + 'bad' + 'extra').parent).not_to exist
  end

  it 'compares to pathnames using <=>' do
    expect((filtering_target + 'good') <=> (app_dir + 'good')).to eq(0)
    expect((filtering_target + 'good') <=> (app_dir + 'bad')).to eq(1)
    expect((filtering_target + 'bad') <=> (app_dir + 'bad')).to eq(0)
    expect((filtering_target + 'a') <=> (app_dir + 'b')).to eq(-1)
    expect((filtering_target + 'b') <=> (app_dir + 'a')).to eq(1)
  end

  it 'supports sorting' do
    a = (filtering_target + 'a')
    b = (filtering_target + 'b')
    expect([b, a].sort).to eq([a, b])
  end

  it 'compares to pathnames using ==' do
    expect((filtering_target + 'good') == (app_dir + 'good')).to be
    expect((filtering_target + 'bad') == (app_dir + 'bad')).to be
  end

  # rubocop:disable Lint/UselessComparison, Style/CaseEquality
  it 'compares to filtering pathnames using <=>' do
    expect((filtering_target + 'good') <=> (filtering_target + 'good')).to eq(0)
    expect((filtering_target + 'good') <=> (filtering_target + 'bad')).to eq(1)
    expect((filtering_target + 'bad') <=> (filtering_target + 'bad')).to eq(0)
    expect((filtering_target + 'a') <=> (filtering_target + 'b')).to eq(-1)
    expect((filtering_target + 'b') <=> (filtering_target + 'a')).to eq(1)
  end

  it 'compares to filtering pathnames using ==' do
    expect((filtering_target + 'good') == (filtering_target + 'good')).to be
    expect((filtering_target + 'bad') == (filtering_target + 'bad')).to be
  end

  it 'compares to pathnames using ===' do
    expect((filtering_target + 'good') === (app_dir + 'good')).to be
    expect((filtering_target + 'bad') === (app_dir + 'bad')).to be
  end

  it 'compares to filtering pathnames using ===' do
    expect((filtering_target + 'good') === (filtering_target + 'good')).to be
    expect((filtering_target + 'bad') === (filtering_target + 'bad')).to be
  end
  # rubocop:enable Lint/UselessComparison, Style/CaseEquality

  it 'delegates relative_path_from' do
    target              = filtering_target + 'test1'
    underlying_pathname = target.send :pathname
    allow(underlying_pathname).to receive(:relative_path_from) { Pathname.new('test1') }
    relative_path = target.relative_path_from(Pathname.new(app_dir))
    expect(relative_path).to eq(Pathname.new('test1'))
  end

  it 'returns path when to_s is called when the path is not filtered out' do
    expect(filtering_target.to_s).to eq(app_dir.to_s)
  end

  it 'returns path when to_s is called when the path is filtered out' do
    expect(filtered_target.to_s).to eq(app_dir.to_s)
  end

  it 'yields a Pathname for each visible result from each_entry' do
    entries = []
    filtering_target.each_entry do |entry|
      entries << entry
    end
    expect(entries.to_set).to eq([Pathname.new('.'), Pathname.new('..'), Pathname.new('good')].to_set)
  end

  it 'delegates each_line when the file is filtered in' do
    target              = filtering_target + 'good'
    underlying_pathname = target.send :pathname
    allow(underlying_pathname).to receive(:each_line).and_yield('test-line')
    expect { |b| target.each_line(&b) }.to yield_successive_args('test-line')
  end

  it 'raises error from each_line when the file is filtered out' do
    expect { (filtering_target + 'bad').each_line { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'returns each visible entry from entries' do
    expect(filtering_target.entries.to_set).to eq([Pathname.new('.'), Pathname.new('..'), Pathname.new('good')].to_set)
  end

  it 'delegates opendir when the directory is filtered in' do
    allow(app_dir).to receive(:opendir).and_yield('test-dir')
    expect { |b| filtering_target.opendir(&b) }.to yield_successive_args('test-dir')
  end

  it 'raises error from opendir when the file is filtered out' do
    expect { (filtering_target + 'bad').opendir { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'delegates sysopen when the file is filtered in' do
    target              = filtering_target + 'good'
    underlying_pathname = target.send :pathname
    allow(underlying_pathname).to receive(:sysopen).and_yield(999)
    expect { |b| target.sysopen(&b) }.to yield_successive_args(999)
  end

  it 'raises error from sysopen when the file is filtered out' do
    expect { (filtering_target + 'bad').sysopen { |_| } }.to raise_exception Errno::ENOENT
  end

  it 'returns each child as a filtered pathname from children' do
    expect(filtering_target.children).to eq([app_dir + 'good'])
  end

  it 'returns each child as a pathname from children(false)' do
    expect(filtering_target.children(false)).to eq([Pathname.new('good')])
  end

  it 'yields each child as a filtered pathname from each_child' do
    expect { |b| filtering_target.each_child(&b) }
      .to yield_successive_args(described_class.new(app_dir + 'good', filter_none, true))
  end

  it 'yields each child as a pathname from each_child(false)' do
    expect { |b| filtering_target.each_child(false, &b) }.to yield_successive_args(Pathname.new('good'))
  end

  it 'yields each component of the path from each_filename' do
    expect { |b| filename_target.each_filename(&b) }.to yield_successive_args('a', 'b')
  end

  it 'yields each element of the path from descend' do
    expect { |b| filename_target.descend(&b) }
      .to yield_successive_args(described_class.new(Pathname.new('/'), filter_none, true),
                                described_class.new(Pathname.new('/a'), filter_none, true),
                                described_class.new(Pathname.new('/a/b'), filter_none, true))
  end

  it 'yields each element of the path from ascend' do
    expect { |b| filename_target.ascend(&b) }
      .to yield_successive_args(described_class.new(Pathname.new('/a/b'), filter_none, true),
                                described_class.new(Pathname.new('/a'), filter_none, true),
                                described_class.new(Pathname.new('/'), filter_none, true))
  end

  it 'raises error if chmod is called on an immutable instance' do
    expect { immutable_target.chmod(0o644) }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if chmod is called on a mutable instance' do
    allow(app_dir).to receive(:chmod)
    mutable_target.chmod(0o644)
  end

  it 'raises error if chown is called on an immutable instance' do
    expect { immutable_target.chown('test-user', 100) }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if chown is called on a mutable instance' do
    allow(app_dir).to receive(:chown)
    mutable_target.chown('test-user', 100)
  end

  it 'raises error if delete is called on an immutable instance' do
    expect { immutable_target.delete }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if delete is called on a mutable instance' do
    allow(app_dir).to receive(:delete)
    mutable_target.delete
  end

  it 'raises error if lchmod is called on an immutable instance' do
    expect { immutable_target.lchmod(0o644) }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if lchmod is called on a mutable instance' do
    allow(app_dir).to receive(:lchmod)
    mutable_target.lchmod(0o644)
  end

  it 'raises error if lchown is called on an immutable instance' do
    expect { immutable_target.lchown('test-user', 100) }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if lchown is called on a mutable instance' do
    allow(app_dir).to receive(:lchown)
    mutable_target.lchown('test-user', 100)
  end

  it 'raises error if make_link is called on an immutable instance' do
    expect { immutable_target.make_link('test') }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if make_link is called on a mutable instance' do
    allow(app_dir).to receive(:make_link)
    mutable_target.make_link('test')
  end

  it 'raises error if make_symlink is called on an immutable instance' do
    expect { immutable_target.make_symlink('test') }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if make_symlink is called on a mutable instance' do
    allow(app_dir).to receive(:make_symlink)
    mutable_target.make_symlink('test')
  end

  it 'raises error if mkdir is called on an immutable instance' do
    expect { immutable_target.mkdir('test') }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if mkdir is called on a mutable instance' do
    allow(app_dir).to receive(:mkdir)
    mutable_target.mkdir('test')
  end

  it 'raises error if open is called on an immutable instance with a mutating mode' do
    expect { immutable_target.open('w') { |_| } }.to raise_error(/FilteringPathname is immutable/)
    expect { immutable_target.open('w+') { |_| } }.to raise_error(/FilteringPathname is immutable/)
    expect { immutable_target.open('a') { |_| } }.to raise_error(/FilteringPathname is immutable/)
    expect { immutable_target.open('a+') { |_| } }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if open is called on an immutable instance with a non-mutating mode' do
    allow(app_dir).to receive(:open)
    immutable_target.open('r') { |_| }
  end

  it 'delegates if open is called on a mutable instance' do
    allow(app_dir).to receive(:open)
    mutable_target.open('w') { |_| }
  end

  it 'delegates if open is called on a mutable instance with permissions' do
    allow(app_dir).to receive(:open).with('w', 0o755)
    mutable_target.open('w', 0o755) { |_| }
  end

  it 'delegates if open is called on a mutable instance with permissions and options' do
    allow(app_dir).to receive(:open).with('w', 0o755, external_encoding: 'UTF-8')
    mutable_target.open('w', 0o755, external_encoding: 'UTF-8') { |_| }
  end

  it 'delegates if open is called on a mutable instance with options but no permissions' do
    allow(app_dir).to receive(:open).with('w', external_encoding: 'UTF-8')
    mutable_target.open('w', external_encoding: 'UTF-8') { |_| }
  end

  it 'copes with options on open' do
    content = (immutable_target + 'good').open('r', external_encoding: 'UTF-8', &:read)
    expect(content).to eq('good')
  end

  it 'raises error if rename is called on an immutable instance' do
    expect { immutable_target.rename('test') }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if rename is called on a mutable instance' do
    allow(app_dir).to receive(:rename)
    mutable_target.rename('test')
  end

  it 'raises error if rmdir is called on an immutable instance' do
    expect { immutable_target.rmdir }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if rmdir is called on a mutable instance' do
    allow(app_dir).to receive(:rmdir)
    mutable_target.rmdir
  end

  it 'raises error if unlink is called on an immutable instance' do
    expect { immutable_target.unlink }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if unlink is called on a mutable instance' do
    allow(app_dir).to receive(:unlink)
    mutable_target.unlink
  end

  it 'raises error if untaint is called on an immutable instance' do
    expect { immutable_target.untaint }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if untaint is called on a mutable instance' do
    allow(app_dir).to receive(:untaint)
    mutable_target.untaint
  end

  it 'raises error if taint is called on an immutable instance' do
    expect { immutable_target.taint }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if taint is called on a mutable instance' do
    allow(app_dir).to receive(:taint)
    mutable_target.taint
  end

  it 'raises error if mkpath is called on an immutable instance' do
    expect { immutable_target.mkpath }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if mkpath is called on a mutable instance' do
    allow(app_dir).to receive(:mkpath)
    mutable_target.mkpath
  end

  it 'raises error if rmtree is called on an immutable instance' do
    expect { immutable_target.rmtree }.to raise_error(/FilteringPathname is immutable/)
  end

  it 'delegates if rmtree is called on a mutable instance' do
    allow(app_dir).to receive(:rmtree)
    mutable_target.rmtree
  end

  it 'globs and filters the result' do
    g = strict_filtering_target + '*'
    expect(g.glob).to eq([app_dir + 'good'])
  end

  it 'globs and yields the result' do
    g = strict_filtering_target + '*'
    expect { |b| g.glob(&b) }.to yield_successive_args(described_class.new(app_dir + 'good', filter_none, true))
  end

  it 'raises error if getwd is used' do
    expect { described_class.getwd }.to raise_error(/undefined method `getwd'/)
  end

  it 'raises error if glob is used' do
    expect { described_class.glob '' }.to raise_error(/undefined method `glob'/)
  end

  it 'raises error if pwd is used' do
    expect { described_class.pwd }.to raise_error(/undefined method `pwd'/)
  end

  def create_file(filename)
    file = app_dir + filename
    FileUtils.mkdir_p file.dirname
    file.open('w') do |f|
      f.write filename
    end

    file
  end

end
