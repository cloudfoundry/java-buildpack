require 'tee'

require 'stringio'
require 'tempfile'

def temppath
  Tempfile.open(File.basename(__FILE__)) do |file|
    file.path.tap do
      file.close!
    end
  end
end

def create_dummy_file
  temppath.tap do |path|
    File.open(path, 'w') do |file|
      file.write('dummy')
    end
  end
end

describe Tee do
  before { $stdout = StringIO.new }
  after  { $stdout = STDOUT }
  let(:tee) { Tee.new }

  describe '.open' do
    context 'with a non-existing file path' do
      let(:path) { temppath }
      after { File.delete(path) }

      it 'creates a file at the path' do
        expect { Tee.open(path) {} }.to change { File.exist?(path) }.from(false).to(true)
      end
    end

    context 'with an existing file path' do
      let(:path) { create_dummy_file }
      after { File.delete(path) }

      context 'without mode' do
        before { @tee = Tee.open(path) }
        after  { @tee.close }

        it 'overwrites an existing file' do
          File.read(path).should be_empty
        end

        context 'when tee writes "foo"' do
          before do
            @tee.write('foo')
            @tee.flush
          end

          it 'writes `foo` in STDOUT' do
            $stdout.string.should == 'foo'
          end

          it 'writes `foo` in the file' do
            File.read(path).should == 'foo'
          end
        end
      end

      context 'in appending mode' do
        before do
          @orignal_content = File.read(path)
          @tee = Tee.open(path, mode: 'a')
        end
        after { @tee.close }

        it 'does not overwrite an existing file' do
          File.read(path).should == @orignal_content
        end

        context 'when tee writes "foo"' do
          before do
            @tee.write('foo')
            @tee.flush
          end

          it 'writes `foo` in STDOUT' do
            $stdout.string.should == 'foo'
          end

          it 'appends `foo` to the file' do
            File.read(path).should == @orignal_content + 'foo'
          end
        end
      end
    end

    context 'without arguments' do
      context 'when tee writes "foo"' do
        before { tee.write('foo') }

        it 'writes `foo` in STDOUT' do
          $stdout.string.should == 'foo'
        end
      end
    end

    context 'with two paths' do
      let(:path1) { temppath }
      let(:path2) { temppath }
      before do
        @tee = Tee.open(path1, path2)
      end
      after do
        @tee.close
        File.delete(path1, path2)
      end

      context 'when tee writes "foo"' do
        before do
          @tee.write('foo')
          @tee.flush
        end

        it 'writes `foo` in STDOUT' do
          $stdout.string.should == 'foo'
        end

        it 'writes `foo` in the first file' do
          File.read(path1).should == 'foo'
        end

        it 'writes `foo` in the second file' do
          File.read(path2).should == 'foo'
        end
      end
    end

    context 'with an option `{ stdout: nil }`' do
      let(:path) { temppath }
      before do
        @tee = Tee.open(path, stdout: nil)
      end
      after do
        @tee.close
        File.delete(path)
      end

      context 'when tee writes "foo"' do
        before do
          @tee.write('foo')
          @tee.flush
        end

        it 'writes nothing in STDOUT' do
          $stdout.string.should be_empty
        end

        it 'writes `foo` in the first file' do
          File.read(path).should == 'foo'
        end
      end
    end

    context 'with File instance' do
      let(:path) { temppath }
      before do
        @file = open(path, 'w')
        @tee  = Tee.open(@file)
      end
      after do
        @file.close
        File.delete(path)
      end

      context 'when tee writes "foo"' do
        before do
          @tee.write('foo')
          @tee.flush
        end

        it 'writes `foo` in STDOUT' do
          $stdout.string.should == 'foo'
        end

        it 'writes `foo` to the File instance' do
          File.read(path).should == 'foo'
        end
      end
    end

    context 'with StringIO instance' do
      before do
        @stringio = StringIO.new
        @tee      = Tee.open(@stringio)
      end

      context 'when tee writes "foo"' do
        before do
          @tee.write('foo')
          @tee.flush
        end

        it 'writes `foo` in STDOUT' do
          $stdout.string.should == 'foo'
        end

        it 'writes `foo` to the StringIO instance' do
          @stringio.string.should == 'foo'
        end
      end
    end
  end

  describe '#<<' do
    it 'returns self' do
      (tee << 'foo').should be tee
    end
  end

  describe '#add' do
    it 'returns self' do
      tee.add.should be tee
    end

    context 'when tee writes "foo", adds a file and writes "bar"' do
      let(:file1) { StringIO.new }
      let(:file2) { StringIO.new }

      before do
        Tee.open(file1) do |tee|
          tee.write('foo')
          tee.add(file2)
          tee.write('bar')
        end
      end

      it 'writes `foobar` in STDOUT' do
        $stdout.string.should == 'foobar'
      end

      it 'writes `foobar` in the first file' do
        file1.string.should == 'foobar'
      end

      it 'writes `bar` in the second file' do
        file2.string.should == 'bar'
      end
    end
  end

  describe '#close' do
    it 'returns nil' do
      tee.close.should be_nil
    end

    it 'closes ios opened by self' do
      path = temppath
      Tee.open(path) do |tee|
        expect { tee.close }.to change {
          tee.instance_variable_get(:@ios)[0][0].closed?
        }.from(false).to(true)
      end
      File.delete(path)
    end

    it 'closes passed ios' do
      file = open(temppath, 'w')
      tee = Tee.open(file)
      expect { tee.close }.to change { file.closed? }.from(false).to(true)
      File.delete(file.path)
    end
  end

  describe '#closed?' do
    context 'when tee is opened without argument' do
      it 'returns true' do
        tee.closed?.should be_true
      end
    end

    context 'when tee is opened with an ios' do
      before { @tee = Tee.open(StringIO.new) }

      it 'returns false' do
        @tee.closed?.should be_false
      end

      context 'after closing' do
        before { @tee.close }

        it 'returns true' do
          @tee.closed?.should be_true
        end
      end
    end
  end

  describe '#flush' do
    it 'returns self' do
      tee.flush.should be tee
    end
  end

  describe '#print' do
    it 'returns nil' do
      tee.print.should be_nil
    end
  end

  describe '#printf' do
    it 'returns nil' do
      tee.printf('format').should be_nil
    end
  end

  describe '#putc' do
    context 'with Fixnum argument' do
      it 'returns argument' do
        char = 0x20
        tee.putc(char).should == char
      end
    end

    context 'with String argument' do
      it 'returns argument' do
        string = 'foo'
        tee.putc(string).should == string
      end
    end
  end

  describe '#puts' do
    it 'returns nil' do
      tee.puts.should be_nil
    end
  end

  describe '#to_io' do
    it 'returns self' do
      tee.to_io.should be tee
    end
  end

  %w( tty? isatty ).each do |method|
    describe "##{method}" do
      it 'returns $stdout.tty?' do
        tee.send(method).should == $stdout.tty?
      end
    end
  end

  %w( syswrite write write_nonblock ).each do |method|
    # for JRuby 1.6
    next if method == 'write_nonblock' && !StringIO.method_defined?(method)

    describe "##{method}" do
      it 'returns Array of the number of bytes written' do
        string = 'foo'
        tee.send(method, string).should == [string.length]
      end
    end
  end
end
