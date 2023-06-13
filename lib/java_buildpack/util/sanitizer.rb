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

# A mixin that adds the ability to turn a +String+ into sanitized uri
class String

  # Takes the uri query params and strips out credentials
  #
  # @return [String] the sanitized query params
  def handle_params(params)
    keywords = /key
               |password
               |username
               |cred(ential)*(s)*
               |password
               |token
               |api[-_]token
               |api
               |auth(entication)*
               |access[-_]token
               |secret[-_]token/ix

    query_params = ''

    params.each do |key, _|
      params[key] = '***' if key.match(keywords)
      query_params += key + '=' + params[key] + '&'
    end

    query_params
  end

  # Takes a uri and strips out any credentials it may contain.
  #
  # @return [String] the sanitized uri
  def sanitize_uri
    rich_uri          = URI(self)
    rich_uri.user     = nil
    rich_uri.password = nil

    if rich_uri.query
      params = (URI.decode_www_form rich_uri.query).to_h
      query_params = handle_params(params)
      rich_uri.query = query_params.chop
    end

    rich_uri.to_s
  end
end
