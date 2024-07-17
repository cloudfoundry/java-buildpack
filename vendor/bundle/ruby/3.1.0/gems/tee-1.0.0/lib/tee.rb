# A class like tee(1)
class Tee
  # @return [String]
  VERSION = '1.0.0'

  class << self
    # @macro new
    #   @param ios [Array<IO, String>]
    #   @param options [Hash]
    #   @option options [String, Fixnum] :mode ('w')
    #   @option options [Fixnum] :perm (0666)
    #   @option options [IO, nil] :stdout ($stdout)
    #
    # @overload open(*ios, options = {})
    #   A synonym for Tee.new
    #   @macro new
    #   @return [Tee]
    #
    # @overload open(*ios, options = {}, &block)
    #   It will be passed the Tee as an argument,
    #   and the Tee will automatically be closed when the block terminates.
    #   @macro new
    #   @yieldparam tee [Tee]
    #   @return the value of the block
    def open(*args, &block)
      if block_given?
        tee = new(*args)
        begin
          yield tee
        ensure
          tee.send(:close_ios_opened_by_self)
        end
      else
        new(*args)
      end
    end
  end

  # @param value [IO, nil] Sets the attribute stdout
  # @return [IO, nil]      Returns the value of attribute stdout
  attr_accessor :stdout

  # @overload initialize(*ios, options = {})
  #   @macro new
  def initialize(*ios)
    @options = { mode: 'w' }
    @options.update(ios.pop) if ios.last.is_a?(Hash)

    @stdout = @options.key?(:stdout) ? @options.delete(:stdout) : $stdout

    @ios = []
    add(*ios)
  end

  # Add ios
  #
  # @param ios [Array<IO, String>]
  # @return [self]
  def add(*ios)
    open_args = [@options[:mode]]
    open_args << @options[:perm] if @options[:perm]

    _ios = []
    begin
      ios.each do |io|
        _ios << (
          io.respond_to?(:write) ?
            [io, false] :
            [File.open(io, *open_args), true]
        )
      end
    rescue => e
      close_ios_opened_by_self(_ios) rescue nil
      raise e
    end
    @ios.concat(_ios)

    self
  end

  # Delegates #<< to ios
  #
  # @param obj [Object]
  # @return [self]
  def <<(obj)
    each_ios_and_stdout(obj, &:<<)
  end

  # Closes all ios except stdout
  #
  # @return [nil]
  def close
    each_ios(&:close)
    nil
  end

  # Returns true if all ios except stdout is closed, false otherwise.
  #
  # @return [Boolean]
  def closed?
    each_ios.all?(&:closed?)
  end

  # Delegates #flush to ios
  #
  # @return [self]
  def flush
    each_ios_and_stdout(&:flush)
  end

  # Delegates #print to ios
  #
  # @param obj [Object]
  # @return [nil]
  def print(*obj)
    each_ios_and_stdout(*obj, &:print)
    nil
  end

  # Delegates #printf to ios
  #
  # @param format [String]
  # @param obj [Object]
  # @return [nil]
  def printf(format, *obj)
    each_ios_and_stdout(format, *obj, &:printf)
    nil
  end

  # Delegates #putc to ios
  #
  # @param char [Fixnum, String]
  # @return [Fixnum]
  # @return [String]
  def putc(char)
    each_ios_and_stdout(char, &:putc)
    char
  end

  # Delegates #puts to ios
  #
  # @param obj [Object]
  # @return [nil]
  def puts(*obj)
    each_ios_and_stdout(*obj, &:puts)
    nil
  end

  # Delegates #syswrite to ios
  #
  # @param string [String]
  # @return [Array<Integer>]
  def syswrite(string)
    each_ios_and_stdout(string).map(&:syswrite)
  end

  # Returns self
  #
  # @return [self]
  def to_io
    self
  end

  # Delegates #tty? to stdout
  #
  # @return [Boolean]
  def tty?
    @stdout ? @stdout.tty? : false
  end
  alias isatty tty?

  # Delegates #write to ios
  #
  # @param string [String]
  # @return [Array<Integer>]
  def write(string)
    each_ios_and_stdout(string).map(&:write)
  end

  # Delegates #write_nonblock to ios
  #
  # @param string [String]
  # @return [Array<Integer>]
  def write_nonblock(string)
    each_ios_and_stdout(string).map(&:write_nonblock)
  end

  private

  # @return [self]
  def each_ios(*args, &block)
    return to_enum(__method__, *args) unless block_given?
    @ios.each do |io,|
      yield io, *args
    end
    self
  end

  # @return [self]
  def each_ios_and_stdout(*args, &block)
    return to_enum(__method__, *args) unless block_given?
    yield @stdout, *args if @stdout
    each_ios(*args, &block)
  end

  # @return [nil]
  def close_ios_opened_by_self(ios = @ios)
    ios.each do |io, opened|
      io.close if opened && !io.closed?
    end
    nil
  end
end
