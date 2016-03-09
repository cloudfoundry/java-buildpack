#!/usr/bin/env bash

set -e

pushd cf-java-client
  rbenv install --skip-existing
  bundle install
  bundle exec rake
popd
