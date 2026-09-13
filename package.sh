#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$(dirname -- "$script_dir")
build_dir="$script_dir/out/build/linux-amd64-release"
game_dir="$sdk_root/Samurai Warriors 2 (USA, Europe)"
output="$script_dir/dist/sw2-test-bundle"
skip_game_data=false
skip_user_data=false
make_zip=false
force=false

usage() { echo 'Usage: package.sh [--output-dir DIR] [--skip-game-data] [--skip-user-data] [--zip] [--force]'; }
while (($#)); do
    case $1 in
        --output-dir) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; output=$2; shift 2 ;;
        --skip-game-data) skip_game_data=true; shift ;;
        --skip-user-data) skip_user_data=true; shift ;;
        --zip) make_zip=true; shift ;;
        --force) force=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

mkdir -p -- "$(dirname -- "$output")"
output=$(cd -- "$(dirname -- "$output")" && pwd)/$(basename -- "$output")
[[ "$output" != / ]] || { echo 'Refusing to use / as the output directory.' >&2; exit 1; }
required=(samurai_warriors_2 libsamurai_warriors_2_SW2XL_US.so librexruntime.so librexgpu-xenos.so)
for file in "${required[@]}"; do
    [[ -f "$build_dir/$file" ]] || { echo "Missing $file. Run ./build.sh first." >&2; exit 1; }
done
if [[ -e "$output" ]]; then
    $force || { echo "Output already exists: $output (use --force to replace it)." >&2; exit 1; }
    rm -rf -- "$output"
fi
mkdir -p -- "$output"
cp -- "${required[@]/#/$build_dir/}" "$output/"

if ! $skip_game_data; then
    [[ -d "$game_dir" ]] || { echo "Game data was not found at $game_dir." >&2; exit 1; }
    cp -a -- "$game_dir" "$output/game"
fi
if ! $skip_user_data && [[ -d "$script_dir/userdata" ]]; then
    cp -a -- "$script_dir/userdata" "$output/userdata"
fi
mkdir -p -- "$output/cache"

cp -- "$script_dir/run-bundle.sh" "$output/run.sh"
printf '%s\n' '# Samurai Warriors 2 test bundle' '' \
    'Run `./run.sh` from Bash. Runtime data, DLC, saves, shader cache, and logs' \
    'remain inside this directory. The bundle contains local game data and is meant' \
    'for private testing.' > "$output/README.md"

if $make_zip; then
    zip_path="$output.zip"
    if [[ -e "$zip_path" ]]; then
        $force || { echo "Archive already exists: $zip_path (use --force to replace it)." >&2; exit 1; }
        rm -f -- "$zip_path"
    fi
    (cd -- "$(dirname -- "$output")" &&
        cmake -E tar cf "$zip_path" --format=zip "$(basename -- "$output")")
    echo "Created archive: $zip_path"
fi
echo "Created portable test bundle: $output"
