#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$(dirname -- "$script_dir")
build_dir="$script_dir/out/build/linux-amd64-release"
exe="$build_dir/samurai_warriors_2"
sdk_runtime_dir="$sdk_root/out/linux-amd64"

[[ -x "$exe" ]] || { echo 'Run build.sh first.' >&2; exit 1; }
[[ -f "$sdk_runtime_dir/librexruntime.so" ]] || {
    echo "ReXGlue runtime library not found: $sdk_runtime_dir/librexruntime.so" >&2
    exit 1
}
export LD_LIBRARY_PATH="$sdk_runtime_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

launch_args=("$@")
has_option() {
    local option=$1 arg
    for arg in "${launch_args[@]}"; do
        [[ "$arg" == "--$option" || "$arg" == "--$option="* ]] && return 0
    done
    return 1
}

if ! has_option fullscreen && ! has_option no-fullscreen; then
    launch_args+=(--no-fullscreen)
fi
if ! has_option mnk_mode && ! has_option no-mnk_mode; then
    launch_args+=(--mnk_mode)
fi

has_option input_backend || launch_args+=(--input_backend sdl)
has_option log_level || launch_args+=(--log_level warn)
has_option render_target_path_vulkan || launch_args+=(--render_target_path_vulkan fbo)
has_option user_data_root || launch_args+=(--user_data_root "$script_dir/userdata")
has_option cache_root || launch_args+=(--cache_root "$script_dir/cache")

cd -- "$build_dir"
exec "$exe" \
    --game_data_root "$sdk_root/Samurai Warriors 2 (USA, Europe)" \
    --gpu_plugin xenos "${launch_args[@]}"
