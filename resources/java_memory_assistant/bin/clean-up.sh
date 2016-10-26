#!/bin/sh -e
# Encoding: utf-8
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

if [ -z "$1" ]; then
    echo "Missing required heap-dump filename argument" >&2
    exit 1
fi

script_folder=$(dirname $0)
max_dump_count_file="${script_folder}/../max_dump_count"

if [ ! -f "${max_dump_count_file}" ]; then
    echo "Max-count file '${max_dump_count_file}' not found" >&2
    exit 2
fi

heap_dump_max_count=$(cat ${max_dump_count_file})

heap_dump_folder=$(dirname $1)

if [ ! -d "${heap_dump_folder}" ]; then
    exit 0
fi

heap_dump_count=$(ls "${heap_dump_folder}" | grep ".hprof" | wc -l)

heap_dump_delete_count=$((heap_dump_count-heap_dump_max_count+1))

if [ ${heap_dump_delete_count} -lt 1 ]; then
    exit 0
fi

for file in $(ls -1 "${heap_dump_folder}" | grep ".hprof" | head -n ${heap_dump_delete_count}); do
    rm -f "${heap_dump_folder}/${file}"
    echo "Heap-dump ${heap_dump_folder}/${file} deleted" >&2
done
