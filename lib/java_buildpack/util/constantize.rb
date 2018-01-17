# frozen_string_literal: true

# Cloud Foundry Java Buildpack
# Copyright 2013-2018 the original author or authors.
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

# A mixin that adds the ability to turn a +String+ into a constant.
class String

  # Tries to find a constant with the name specified by this +String+:
  #
  #   "Module".constantize     # => Module
  #   "Test::Unit".constantize # => Test::Unit
  #
  # The name is assumed to be the one of a top-level constant, no matter whether
  # it starts with "::" or not. No lexical context is taken into account:
  #
  #   C = 'outside'
  #   module M
  #     C = 'inside'
  #     C               # => 'inside'
  #     "C".constantize # => 'outside', same as ::C
  #   end
  #
  # @return [String] The constantized rendering of this +String+.
  # @raise NameError if the name is not in CamelCase or the constant is unknown.
  def constantize
    names = split('::')
    names.shift if names.empty? || names.first.empty?

    constant = Object
    names.each do |name|
      constant = constant.const_defined?(name, false) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end
end
