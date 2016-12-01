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

# A mixin that adds the ability to turn a +String+ into sanitized uri
class String

  # Takes a uri and strips out any credentials it may contain.
  #
  # @return [String] the sanitized uri
  def sanitize_uri
    rich_uri          = URI(self)
    rich_uri.user     = nil
    rich_uri.password = nil
    rich_uri.to_s
  end

end
