# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
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

# A mixin that adds the ability to turn a +String+ into dash case
class String

  # Converts a string to dash case.  For example, the Spring +DashCase+ would become +dash-case+.
  #
  # @return [String] The dash case rendering of this +String+
  def dash_case
    split('::')
      .last
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1-\2')
      .gsub(/([a-z\d])([A-Z])/, '\1-\2')
      .downcase
  end

end
