#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$(dirname -- "$script_dir")
profile_dir="$script_dir/pgo/raw"

mkdir -p -- "$profile_dir"
find "$profile_dir" -maxdepth 1 -type f -name '*.profraw' -delete
cmake --preset linux-amd64-release -S "$script_dir" \
    "-DREXSDK_DIR=$sdk_root" -DSW2_PGO=GENERATE
cmake --build --preset linux-amd64-release -j 6

echo 'Instrumented build ready. Train it with ./run-pgo-training.sh'
