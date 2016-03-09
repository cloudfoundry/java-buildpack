#!/usr/bin/env bash

set -e

eval "$(rbenv init -)"

pushd java-buildpack
  rbenv install --skip-existing
  bundle install
  bundle exec rake
popd
