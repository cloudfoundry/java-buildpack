tee
===

A class like tee(1) for Ruby.

[![Build Status](https://secure.travis-ci.org/m4i/tee.png)](http://travis-ci.org/m4i/tee)


Installation
------------

Add this line to your application's Gemfile:

    gem 'tee'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tee


Examples
--------

### Basic usage

```ruby
Tee.open('a.txt') do |tee|
  tee.puts 'foo'
end
```

```
# a.txt
foo

# STDOUT
foo
```

### Multiple files

```ruby
Tee.open('a.txt', 'b.txt') do |tee|
  tee.puts 'bar'
end
```

```
# a.txt
bar

# b.txt
bar

# STDOUT
bar
```

### Appending mode

```ruby
Tee.open('a.txt', mode: 'a') do |tee|
  tee.puts 'baz'
end
```

```
# a.txt
bar
baz

# STDOUT
baz
```

### Disable STDOUT

```ruby
Tee.open('a.txt', 'b.txt', stdout: nil) do |tee|
  tee.puts 'qux'
end
```

```
# a.txt
qux

# b.txt
qux
```

### IO instances

```ruby
require 'stringio'

stringio = StringIO.new

open('a.txt', 'w') do |file|
  Tee.open(file, stringio) do |tee|
    tee.puts 'quux'
  end  # `file` doesn't close because it wasn't opened by Tee.
  file.puts 'corge'
end

puts stringio.string
```

```
# a.txt
quux
corge

# STDOUT
quux
quux
```


Copyright
---------

Copyright (c) 2012 Masaki Takeuchi. See LICENSE for details.
