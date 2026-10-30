#!/usr/bin/env zsh
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

REPO_DIR="${0:A:h}"
WS_DIR="$HOME/.zmk-workspace"
SDK_DIR="$WS_DIR/zephyr-sdk-0.16.8"
LINK_DIR="$WS_DIR/repo-link"

if [ ! -d "$WS_DIR/.venv" ] || [ ! -d "$WS_DIR/zmk" ]; then
    echo "Error: Local ZMK workspace not found at $WS_DIR"
    exit 1
fi

# Symlink repo to a path without spaces ("Mobile Documents" breaks Zephyr DTC_OVERLAY_FILE splitting)
ln -sfn "$REPO_DIR" "$LINK_DIR"

source "$WS_DIR/.venv/bin/activate"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="$SDK_DIR"
export CMAKE_PREFIX_PATH="/opt/homebrew:${WS_DIR}/zephyr/share/zephyr-package/cmake:${CMAKE_PREFIX_PATH:-}"

EXTRA_MODULES="${LINK_DIR};${WS_DIR}/zmk-dongle-display;${WS_DIR}/zmk-nice-oled;${WS_DIR}/zmk-dongle-display-view;${WS_DIR}/zmk-oled-adapter"

build_target() {
    local name="$1"
    local board="$2"
    local shield="$3"
    local snippet="$4"
    local extra_cmake="$5"
    local build_dir="$WS_DIR/build/$name"

    echo "------------------------------------------------------------"
    echo "Building: $name ($board | $shield)"
    echo "------------------------------------------------------------"

    if [ ! -f "$build_dir/build.ninja" ] || ! grep -Fq "SHIELD:STRING=${shield}" "$build_dir/CMakeCache.txt" 2>/dev/null; then
        rm -rf "$build_dir"
    fi

    cd "$WS_DIR"
    local -a cmd=(
        west build -s zmk/app -d "$build_dir" -b "$board"
    )
    if [ -n "$snippet" ]; then
        cmd+=(-S "$snippet")
    fi
    cmd+=(
        --
        -DSHIELD="$shield"
        -DZMK_CONFIG="$LINK_DIR/config"
        -DZMK_EXTRA_MODULES="$EXTRA_MODULES"
    )
    if [ -n "$extra_cmake" ]; then
        cmd+=("$extra_cmake")
    fi

    "${cmd[@]}"

    mkdir -p "$REPO_DIR/firmware"
    cp "$build_dir/zephyr/zmk.uf2" "$REPO_DIR/firmware/${name}.uf2"
    echo "✅ Saved: firmware/${name}.uf2"
}

TARGET="${1:-left}"

case "$TARGET" in
    left)
        build_target "nice_corne_left_oled" "nice_nano_v2" "corne_left nice_oled" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Corne_Oled"'
        ;;
    right)
        build_target "nice_corne_right_oled" "nice_nano_v2" "corne_right nice_oled" "" ""
        ;;
    both)
        build_target "nice_corne_left_oled" "nice_nano_v2" "corne_left nice_oled" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Corne_Oled"'
        build_target "nice_corne_right_oled" "nice_nano_v2" "corne_right nice_oled" "" ""
        ;;
    left_peripheral)
        build_target "nice_corne_left_peripheral_oled" "nice_nano_v2" "corne_left_peripheral nice_oled" "" ""
        ;;
    dongle)
        build_target "nice_corne_dongle_oled" "nice_nano_v2" "corne_dongle_pro_micro dongle_display" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Dongle_O"'
        build_target "nice_corne_dongle_pro_micro" "nice_nano_v2" "corne_dongle_pro_micro" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Dongle"'
        ;;
    all)
        build_target "nice_corne_left_oled" "nice_nano_v2" "corne_left nice_oled" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Corne_Oled"'
        build_target "nice_corne_right_oled" "nice_nano_v2" "corne_right nice_oled" "" ""
        build_target "nice_corne_left_peripheral_oled" "nice_nano_v2" "corne_left_peripheral nice_oled" "" ""
        build_target "nice_corne_dongle_oled" "nice_nano_v2" "corne_dongle_pro_micro dongle_display" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Dongle_O"'
        build_target "nice_corne_dongle_pro_micro" "nice_nano_v2" "corne_dongle_pro_micro" "studio-rpc-usb-uart" '-DCONFIG_ZMK_KEYBOARD_NAME="Nice_Dongle"'
        ;;
    *)
        echo "Usage: ./build.sh [left|right|both|left_peripheral|dongle|all]"
        exit 1
        ;;
esac
