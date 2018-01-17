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

# A mixin that adds the ability to turn a +String+ into a boolean
class String

  # Converts a +String+ to a boolean
  #
  # @return [Boolean] +true+ if +<STRING>.casecmp 'true'+.  +false+ otherwise
  def to_b
    casecmp 'true'
  end

end

# A mixin that adds the ability to turn a +nil+ into a boolean
class NilClass

  # Converts a +nil+ to a boolean
  #
  # @return [Boolean] +false+ always
  def to_b
    false
  end

end
