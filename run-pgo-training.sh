#!/usr/bin/env bash
set -euo pipefail
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mkdir -p -- "$script_dir/pgo/raw"
export LLVM_PROFILE_FILE="$script_dir/pgo/raw/sw2-%m-%p.profraw"
exec "$script_dir/run.sh" "$@"
