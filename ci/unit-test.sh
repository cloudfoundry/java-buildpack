#!/usr/bin/env bash

set -e

export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

eval "$(rbenv init -)"

pushd java-buildpack
  bundle install
  bundle exec rake
popd
