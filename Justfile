# Recipes for the `just` task-runner:
# https://github.com/casey/just
#
# First time: `just init`, then `just build` (or `just build right`).

# Run every recipe through `mise exec`, so the tools and env vars from
# mise.toml are available even in a shell without `mise activate`.
# Shebang recipes don't use this setting, so they start with
# `#!/usr/bin/env -S mise exec -- bash` for the same reason.
set shell := ["mise", "exec", "--", "bash", "-euo", "pipefail", "-c"]

_default: help

repo-url := "https://github.com/infused-kim/zmk-config"
zmk-docs-url := "https://v0-3-branch.zmk.dev/docs/"

root := justfile_directory()
workspace := root / ".zmk"
config := root / "config"
build-dir := root / ".build"
out := root / "firmware"

#
# Setup
#

# Install the tools and Zephyr SDK, then create the west workspace in .zmk/
[group("setup")]
init: _workspace update

# Fetch ZMK, Zephyr and the modules from config/west.yml and their Python deps
[group("setup")]
update:
    @just _local-modules >/dev/null
    cd "{{ workspace }}" && west update --fetch-opt=--filter=blob:none
    uv pip install --quiet -r "{{ workspace }}/zephyr/scripts/requirements-base.txt"
alias u := update

# Create the west workspace. Only config/west.yml is linked into it, so the
# Zephyr checkout lands in .zmk/zephyr instead of colliding with zephyr/module.yml.
[private]
_workspace:
    #!/usr/bin/env -S mise exec -- bash
    set -euo pipefail
    mise install
    if [[ ! -d "${ZEPHYR_SDK_INSTALL_DIR:-}/arm-zephyr-eabi" ]]; then
        echo "The Zephyr SDK is missing its arm toolchain. Reinstall it with:" >&2
        echo "  mise install --force zephyr-sdk" >&2
        exit 1
    fi
    uv pip install --quiet west
    mkdir -p "{{ workspace }}/config"
    ln -sfn ../../config/west.yml "{{ workspace }}/config/west.yml"
    if [[ ! -d "{{ workspace }}/.west" ]]; then
        cd "{{ workspace }}" && west init -l config
    fi

#
# Build
#

# List the build targets from build.yaml
[group("build")]
list:
    @just _targets | cut -f1

# Build the targets whose name contains `filter` (default: all). Extra args go to `west build`, e.g. `just build right -p`
[group("build")]
build filter="all" *west-args:
    #!/usr/bin/env -S mise exec -- bash
    set -euo pipefail
    targets=$(just _targets)
    if [[ "{{ filter }}" != all ]]; then
        targets=$(grep -i -- "{{ filter }}" <<<"$targets" || true)
    fi
    if [[ -z "$targets" ]]; then
        echo "No build target matches '{{ filter }}'. Targets:" >&2
        just list >&2
        exit 1
    fi
    # This repo is a module (boards/shields), plus any local module overrides
    local_modules=$(just _local-modules)
    extra_modules="{{ root }}${local_modules:+;$local_modules}"
    mkdir -p "{{ out }}"
    cd "{{ workspace }}"
    while IFS=$'\t' read -r name board shield snippet cmake_args; do
        echo "==> Building $name"
        west build -s zmk/app -d "{{ build-dir }}/$name" -b "$board" \
            ${snippet:+-S "$snippet"} {{ west-args }} -- \
            -DZMK_CONFIG="{{ config }}" -DZMK_EXTRA_MODULES="$extra_modules" \
            ${shield:+-DSHIELD="$shield"} $cmake_args
        fw="{{ build-dir }}/$name/zephyr/zmk.uf2"
        [[ -f "$fw" ]] || fw="{{ build-dir }}/$name/zephyr/zmk.bin"
        cp "$fw" "{{ out }}/$name.${fw##*.}"
        echo "==> Wrote firmware/$name.${fw##*.}"
    done <<<"$targets"
alias b := build

# Copy a built firmware to a nice!nano in bootloader mode (double-tap reset)
[group("build")]
flash target volume="/Volumes/NICENANO":
    #!/usr/bin/env -S mise exec -- bash
    set -euo pipefail
    fw="{{ out }}/{{ target }}.uf2"
    if [[ ! -f "$fw" ]]; then
        echo "$fw not found. Run 'just build {{ target }}' first." >&2
        exit 1
    fi
    echo "Waiting for {{ volume }} (double-tap reset on the controller)..."
    until [[ -d "{{ volume }}" ]]; do sleep 1; done
    # The controller reboots as soon as the copy finishes, which can make cp complain
    cp "$fw" "{{ volume }}/" 2>/dev/null || true
    echo "Flashed {{ target }}"
alias f := flash

# Delete build output (.build/ and firmware/)
[group("build")]
clean:
    rm -rf "{{ build-dir }}" "{{ out }}"

# Delete the west workspace in .zmk/ (re-create with `just init`)
[group("build")]
[confirm("Delete .zmk/ (west workspace)?")]
clean-workspace:
    rm -rf "{{ workspace }}"

# Show which modules come from local checkouts (ZMK_LOCAL_MODULES in mise.local.toml)
[group("build")]
local-modules:
    @just _local-modules >/dev/null

# Apply ZMK_LOCAL_MODULES (see mise.local.toml.example): deactivate the west
# projects it replaces, then print the local module paths as a CMake list.
# Without overrides, it clears the filter again so west.yml is used as is.
[private]
_local-modules:
    #!/usr/bin/env -S mise exec -- bash
    set -euo pipefail
    filter=()
    paths=()
    for entry in ${ZMK_LOCAL_MODULES:-}; do
        if [[ "$entry" == *=* ]]; then
            project="${entry%%=*}"
            path="${entry#*=}"
        else
            project=""
            path="$entry"
        fi
        if ! abs=$(cd "{{ root }}" && cd "$path" 2>/dev/null && pwd); then
            echo "Local module not found: $path" >&2
            exit 1
        fi
        if [[ ! -f "$abs/zephyr/module.yml" ]]; then
            echo "Not a Zephyr module (no zephyr/module.yml): $abs" >&2
            exit 1
        fi
        [[ -n "$project" ]] && filter+=("-$project")
        paths+=("$abs")
        echo "Local module: ${project:-(not in west.yml)} -> $abs" >&2
    done
    cd "{{ workspace }}"
    if (( ${#filter[@]} )); then
        west config manifest.project-filter -- "$(IFS=,; echo "${filter[*]}")"
    else
        west config -d manifest.project-filter 2>/dev/null || true
    fi
    (IFS=';'; echo "${paths[*]}")

# One tab-separated line per build.yaml target: name, board, shield, snippet, cmake-args
[private]
_targets:
    @yq -r '.include[] | [ \
        .["artifact-name"] // ([.shield, .board] | map(select(.)) | join("-") | sub(" ", "-")), \
        .board, .shield // "", .snippet // "", .["cmake-args"] // "" \
    ] | @tsv' "{{ root }}/build.yaml"

#
# Keymap
#

# Draw the keymap into keymap_img/keymap.svg
[group("keymap")]
draw:
    #!/usr/bin/env -S mise exec -- bash
    set -euo pipefail
    # Runs from the repo root, so the include path in keymap_config.yaml resolves
    cd "{{ root }}"
    if [[ ! -d .zmk/zmk-helpers/include ]]; then
        echo "zmk-helpers isn't checked out yet. Run 'just init' first." >&2
        exit 1
    fi
    # Write to temp files first, so a failed run doesn't leave an empty keymap.svg
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    keymap -c keymap_img/keymap_config.yaml parse -c 12 -z config/corne.keymap > "$tmp/keymap.yaml"
    keymap -c keymap_img/keymap_config.yaml draw --qmk-keyboard crkbd/rev1 --qmk-layout LAYOUT_split_3x6_3 \
        "$tmp/keymap.yaml" -s Base Nav Num Func Sym Adjust > "$tmp/keymap.svg"
    mv "$tmp/keymap.yaml" keymap_img/keymap.yaml
    mv "$tmp/keymap.svg" keymap_img/keymap.svg
    echo "Wrote keymap_img/keymap.svg"

#
# Other
#

# Show this help
[group("other")]
help:
    @echo "Info:"
    @echo "    - Git repo: {{ repo-url }}"
    @echo "    - ZMK docs: {{ zmk-docs-url }}"
    @echo
    @just --list --unsorted

# Print and open the Git repository URL
[group("links")]
open-repo:
    @echo "git repo: {{ repo-url }}"
    @open "{{ repo-url }}"
alias or := open-repo

# Print and open the ZMK v0.3 documentation
[group("links")]
open-zmk-docs:
    @echo "zmk docs: {{ zmk-docs-url }}"
    @open "{{ zmk-docs-url }}"
alias od := open-zmk-docs
