#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exe="$root/samurai_warriors_2"
game="$root/game"
[[ -f "$game/default.xex" ]] || { echo 'Game data is missing from the bundle/game directory.' >&2; exit 1; }
export LD_LIBRARY_PATH="$root${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

args=("$@")
has_option() {
    local option=$1 arg
    for arg in "${args[@]}"; do
        [[ "$arg" == "--$option" || "$arg" == "--$option="* ]] && return 0
    done
    return 1
}
if ! has_option fullscreen && ! has_option no-fullscreen; then args+=(--no-fullscreen); fi
if ! has_option mnk_mode && ! has_option no-mnk_mode; then args+=(--mnk_mode); fi
has_option input_backend || args+=(--input_backend sdl)
has_option log_level || args+=(--log_level warn)
has_option render_target_path_vulkan || args+=(--render_target_path_vulkan fbo)
has_option user_data_root || args+=(--user_data_root "$root/userdata")
has_option cache_root || args+=(--cache_root "$root/cache")

cd -- "$root"
exec "$exe" --game_data_root "$game" --gpu_plugin xenos "${args[@]}"
