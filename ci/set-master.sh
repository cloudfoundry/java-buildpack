#!/bin/bash

git_root="$(git rev-parse --show-toplevel)"
target="$1"
secdir="${2:-${git_root}/../cloudfoundry/secure}"
secfile="concourse-secrets.yml.gpg"
secrets="${secdir}/${secfile}"

if [ ! -f "${secrets}" ]
then
  echo -e 1>&2 "$0: Failed to find the secrets file ${secrets}\n\tPlease specify the correct directory holding \"${secfile}\"."
  exit 1
fi

fly -t "$target" set-pipeline -p java-buildpack -c "${git_root}/ci/java-buildpack.yml" \
	    -l <(gpg -d --no-tty "${secrets}" 2> /dev/null) -l "${git_root}/ci/public-config.yml" 
