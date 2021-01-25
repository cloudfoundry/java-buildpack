#!/usr/bin/env bash

set -euo pipefail

RELEASE=$1

echo "---" > config/version.yml
echo "version: v$RELEASE" >> config/version.yml

bundle exec rake clobber package
mv build/*-buildpack-v$RELEASE.zip $HOME/Desktop

bundle exec rake clobber package OFFLINE=true PINNED=true
mv build/*-buildpack-offline-v$RELEASE.zip $HOME/Desktop

bundle exec rake versions:markdown versions:json

git add .
git commit --message "v$RELEASE Release"
git tag "v$RELEASE"
git reset --hard HEAD^1
