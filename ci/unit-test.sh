#!/usr/bin/env bash

set -e

pushd java-buildpack
  rbenv install --skip-existing
  bundle install
  bundle exec rake
popd
