# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2020 the original author or authors.
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

class String

  @color_enabled = true

  class << self
    attr_accessor :color_enabled
  end

  # Sets the string to bold
  def bold
    return self unless self.class.color_enabled

    "\e[1m#{self}\e[22m"
  end

  # Sets the string to italic
  def italic
    return self unless self.class.color_enabled

    "\e[3m#{self}\e[23m"
  end

  # Sets the string to underlined
  def underline
    return self unless self.class.color_enabled

    "\e[4m#{self}\e[24m"
  end

  # Sets the string to blink
  def blink
    return self unless self.class.color_enabled

    "\e[5m#{self}\e[25m"
  end

  # Sets the string reverse the current colors
  def reverse_color
    return self unless self.class.color_enabled

    "\e[7m#{self}\e[27m"
  end

  # Sets the string to black
  def black
    return self unless self.class.color_enabled

    "\e[30m#{self}\e[0m"
  end

  # Sets the string to red
  def red
    return self unless self.class.color_enabled

    "\e[31m#{self}\e[0m"
  end

  # Sets the string to green
  def green
    return self unless self.class.color_enabled

    "\e[32m#{self}\e[0m"
  end

  # Sets the string to yellow
  def yellow
    return self unless self.class.color_enabled

    "\e[33m#{self}\e[0m"
  end

  # Sets the string to blue
  def blue
    return self unless self.class.color_enabled

    "\e[34m#{self}\e[0m"
  end

  # Sets the string to magenta
  def magenta
    return self unless self.class.color_enabled

    "\e[35m#{self}\e[0m"
  end

  # Sets the string to cyan
  def cyan
    return self unless self.class.color_enabled

    "\e[36m#{self}\e[0m"
  end

  # Sets the string to white
  def white
    return self unless self.class.color_enabled

    "\e[37m#{self}\e[0m"
  end

  # Sets the string background to black
  def bg_black
    return self unless self.class.color_enabled

    "\e[40m#{self}\e[0m"
  end

  # Sets the string background to red
  def bg_red
    return self unless self.class.color_enabled

    "\e[41m#{self}\e[0m"
  end

  # Sets the string background to green
  def bg_green
    return self unless self.class.color_enabled

    "\e[42m#{self}\e[0m"
  end

  # Sets the string background to yellow
  def bg_yellow
    return self unless self.class.color_enabled

    "\e[43m#{self}\e[0m"
  end

  # Sets the string background to blue
  def bg_blue
    return self unless self.class.color_enabled

    "\e[44m#{self}\e[0m"
  end

  # Sets the string background to magenta
  def bg_magenta
    return self unless self.class.color_enabled

    "\e[45m#{self}\e[0m"
  end

  # Sets the string background to cyan
  def bg_cyan
    return self unless self.class.color_enabled

    "\e[46m#{self}\e[0m"
  end

  # Sets the string background to white
  def bg_white
    return self unless self.class.color_enabled

    "\e[47m#{self}\e[0m"
  end

end
