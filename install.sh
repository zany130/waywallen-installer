#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Defaults / Config
###############################################################################
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
SRC_DIR="${SRC_DIR:-$ROOT_DIR/src}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"
JOBS="${JOBS:-$(nproc)}"

CMAKE_VER="4.2.4"
CMAKE_TGZ="cmake-${CMAKE_VER}-linux-x86_64.tar.gz"
CMAKE_DIR="$HOME/.local/opt/cmake-${CMAKE_VER}-linux-x86_64"
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/${CMAKE_TGZ}"

# Default behavior:
# - native path builds in distrobox
# - KDE plugin installs on host
# - Flatpak path is opt-in and is Flatpak-only (+ optional KDE plugin)
INSTALL_KDE_PLUGIN="${INSTALL_KDE_PLUGIN:-1}"
USE_DISTROBOX="${USE_DISTROBOX:-1}"
BUILD_FLATPAK="${BUILD_FLATPAK:-0}"

UPDATE_REPOS="${UPDATE_REPOS:-1}"
CLEAN_BUILD_DIRS="${CLEAN_BUILD_DIRS:-1}"

DISTROBOX_NAME="${DISTROBOX_NAME:-fedora-44-waywallen}"
DISTROBOX_IMAGE="${DISTROBOX_IMAGE:-registry.fedoraproject.org/fedora-toolbox:44}"
DISTROBOX_HOME="${DISTROBOX_HOME:-$ROOT_DIR/.distrobox-home}"

FLATPAK_REPO_URL="${FLATPAK_REPO_URL:-https://github.com/hypengw/org.waywallen.waywallen.git}"
FLATPAK_SRC_DIR="${FLATPAK_SRC_DIR:-$ROOT_DIR/src/org.waywallen.waywallen}"
FLATPAK_MANIFEST="${FLATPAK_MANIFEST:-org.waywallen.waywallen.yml}"
FLATPAK_BUILD_DIR="${FLATPAK_BUILD_DIR:-$ROOT_DIR/flatpak/build-dir}"
FLATPAK_BUILDER_APP_ID="${FLATPAK_BUILDER_APP_ID:-org.flatpak.Builder}"

# Internal flag so distrobox re-entry does not create a second log
WAYWALLEN_INNER_RUN="${WAYWALLEN_INNER_RUN:-0}"

###############################################################################
# Logging
###############################################################################
if [[ "$WAYWALLEN_INNER_RUN" != "1" ]]; then
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_FILE:-$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log}"
  exec > >(tee -a "$LOG_FILE") 2>&1
else
  LOG_FILE="${LOG_FILE:-$LOG_DIR/install-inner.log}"
fi

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
msg()  { printf '\n[%s] ==> %s\n' "$(timestamp)" "$*"; }
warn() { printf '\n[%s] WARNING: %s\n' "$(timestamp)" "$*" >&2; }
die()  { printf '\n[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  local line_no=$1
  warn "Command failed at line ${line_no}: ${BASH_COMMAND}"
  warn "Exit code: ${exit_code}"
  warn "Full log: $LOG_FILE"
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

run_step() {
  local name="$1"
  shift
  msg "START: $name"
  "$@"
  msg "DONE:  $name"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

###############################################################################
# Help / CLI
###############################################################################
show_help() {
cat <<EOF
Waywallen installer

Defaults:
  - Native mode builds inside Fedora 44 distrobox
  - KDE wallpaper plugin installs on host
  - Flatpak is skipped unless requested

Modes:
  - Default: native install (+ optional KDE plugin)
  - --flatpak: Flatpak-only install on host (+ optional KDE plugin)

Usage:
  $0 [options]

Options:
  -h, --help                Show this help message
  --flatpak                 Build/install Flatpak only on host
  --no-distrobox            Build native components on the current host
  --no-kde                  Skip KDE wallpaper package install
  --no-update               Do not git pull existing repos
  --no-clean                Reuse existing build directories
  --prefix PATH             Install prefix (default: $PREFIX)
  --src-dir PATH            Source checkout dir (default: $SRC_DIR)
  --build-dir PATH          Build dir (default: $BUILD_DIR)
  --jobs N                  Parallel build jobs (default: $JOBS)

  --flatpak-src-dir PATH    Flatpak repo dir (default: $FLATPAK_SRC_DIR)
  --flatpak-build-dir PATH  Flatpak build dir (default: $FLATPAK_BUILD_DIR)

  --distrobox-name NAME     Distrobox name (default: $DISTROBOX_NAME)
  --distrobox-home PATH     Distrobox home dir (default: $DISTROBOX_HOME)

Examples:
  $0
  $0 --flatpak
  $0 --flatpak --no-kde
  $0 --no-distrobox
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --flatpak)
      BUILD_FLATPAK=1
      shift
      ;;
    --no-distrobox)
      USE_DISTROBOX=0
      shift
      ;;
    --no-kde)
      INSTALL_KDE_PLUGIN=0
      shift
      ;;
    --no-update)
      UPDATE_REPOS=0
      shift
      ;;
    --no-clean)
      CLEAN_BUILD_DIRS=0
      shift
      ;;
    --prefix)
      [[ $# -ge 2 ]] || die "--prefix requires a value"
      PREFIX="$2"
      shift 2
      ;;
    --src-dir)
      [[ $# -ge 2 ]] || die "--src-dir requires a value"
      SRC_DIR="$2"
      shift 2
      ;;
    --build-dir)
      [[ $# -ge 2 ]] || die "--build-dir requires a value"
      BUILD_DIR="$2"
      shift 2
      ;;
    --jobs)
      [[ $# -ge 2 ]] || die "--jobs requires a value"
      JOBS="$2"
      shift 2
      ;;
    --flatpak-src-dir)
      [[ $# -ge 2 ]] || die "--flatpak-src-dir requires a value"
      FLATPAK_SRC_DIR="$2"
      shift 2
      ;;
    --flatpak-build-dir)
      [[ $# -ge 2 ]] || die "--flatpak-build-dir requires a value"
      FLATPAK_BUILD_DIR="$2"
      shift 2
      ;;
    --distrobox-name)
      [[ $# -ge 2 ]] || die "--distrobox-name requires a value"
      DISTROBOX_NAME="$2"
      shift 2
      ;;
    --distrobox-home)
      [[ $# -ge 2 ]] || die "--distrobox-home requires a value"
      DISTROBOX_HOME="$2"
      shift 2
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

###############################################################################
# Helpers
###############################################################################
clone_or_update() {
  local url="$1"
  local dir="$2"

  if [[ ! -d "$dir/.git" ]]; then
    msg "Cloning $(basename "$dir")"
    git clone "$url" "$dir"
    if command -v git-lfs >/dev/null 2>&1; then
      git -C "$dir" lfs pull || true
    fi
  elif [[ "$UPDATE_REPOS" == "1" ]]; then
    msg "Updating $(basename "$dir")"
    git -C "$dir" pull --ff-only
    if command -v git-lfs >/dev/null 2>&1; then
      git -C "$dir" lfs pull || true
    fi
  else
    msg "Using existing repo $(basename "$dir")"
  fi
}

clean_build_dir() {
  local dir="$1"
  if [[ "$CLEAN_BUILD_DIRS" == "1" ]]; then
    rm -rf "$dir"
  fi
}

###############################################################################
# Dependency helpers
###############################################################################
HOST_TOOLS=(
  git curl tar tee
)

BUILD_TOOLS=(
  cmake ninja cargo clang clang++ pkg-config git curl tar
)

PKGCONFIG_MODULES=(
  mpv
  egl
  glesv2
  gbm
  vulkan
  xkbcommon
  libavformat
  libavcodec
  libavutil
  libswscale
  liblz4
)

FEDORA_44_BUILD_PACKAGES=(
  cmake
  ninja-build
  clang
  lld
  pkgconf-pkg-config
  git
  git-lfs
  cargo
  rust
  lz4-devel
  mpv-devel
  libcurl-devel
  qt6-qtbase-devel
  qt6-qtbase-private-devel
  qt6-qtdeclarative-devel
  qt6-qtdeclarative-private-devel
  qt6-qttools-devel
  qt6-qtgrpc-devel
  qt6-qtshadertools-devel
  vulkan-headers
  vulkan-loader-devel
  glslang-devel
  libshaderc-devel
  ffmpeg-free-devel
  libavcodec-free-devel
  libavformat-free-devel
  libavutil-free-devel
  libswscale-free-devel
  libxkbcommon-devel
  wayland-devel
  wayland-protocols-devel
  mesa-libEGL-devel
  mesa-libGLES-devel
  mesa-libgbm-devel
  protobuf-devel
  protobuf-compiler
)

check_host_tools() {
  local missing=()
  for cmd in "${HOST_TOOLS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    die "Missing required host tools: ${missing[*]}"
  fi
}

check_build_tools() {
  local missing=()
  for cmd in "${BUILD_TOOLS[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    warn "Missing build tools on current environment: ${missing[*]}"
    return 1
  fi

  msg "Build tool preflight passed"
  return 0
}

check_pkgconfig_modules() {
  local missing=()

  for mod in "${PKGCONFIG_MODULES[@]}"; do
    if ! pkg-config --exists "$mod"; then
      missing+=("$mod")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    warn "Missing pkg-config modules on current environment: ${missing[*]}"
    return 1
  fi

  msg "pkg-config preflight passed"
  return 0
}

print_fedora_44_packages() {
  msg "Fedora 44 packages to install:"
  printf '  %s\n' "${FEDORA_44_BUILD_PACKAGES[@]}"
}

###############################################################################
# Distrobox helpers
###############################################################################
ensure_distrobox_host_deps() {
  require_cmd distrobox
  require_cmd podman
}

distrobox_exists() {
  distrobox list --no-color 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$DISTROBOX_NAME"
}

distrobox_exec() {
  distrobox enter "$DISTROBOX_NAME" -- bash -lc "$*"
}

create_fedora44_distrobox() {
  mkdir -p "$DISTROBOX_HOME"

  if distrobox_exists; then
    msg "Distrobox $DISTROBOX_NAME already exists"
    return 0
  fi

  run_step "Create Fedora 44 distrobox" \
    distrobox create \
      --name "$DISTROBOX_NAME" \
      --image "$DISTROBOX_IMAGE" \
      --home "$DISTROBOX_HOME" \
      --volume "$ROOT_DIR:$ROOT_DIR"
}

install_distrobox_build_deps() {
  local pkgs
  pkgs="$(printf '%q ' "${FEDORA_44_BUILD_PACKAGES[@]}")"

  run_step "Install Fedora 44 build dependencies inside distrobox" \
    distrobox_exec "sudo dnf -y install ${pkgs}"
}

configure_rust_toolchain_in_distrobox() {
  run_step "Configure Rust toolchain inside distrobox" \
    distrobox_exec '
      if command -v rustup >/dev/null 2>&1; then
        rustup default stable
      fi
      cargo --version
      rustc --version
    '
}

verify_git_lfs_in_distrobox() {
  run_step "Verify git-lfs inside distrobox" \
    distrobox_exec 'git lfs env >/dev/null && git lfs version'
}

initialize_git_lfs_in_distrobox() {
  run_step "Initialize git-lfs inside distrobox" \
    distrobox_exec 'git lfs install --skip-repo'
}

###############################################################################
# Native build implementation
###############################################################################
bootstrap_local_cmake() {
  mkdir -p "$HOME/.local/opt"
  cd "$HOME/.local/opt"

  if [[ ! -d "$CMAKE_DIR" ]]; then
    msg "Installing CMake ${CMAKE_VER} to $CMAKE_DIR"
    run_step "Download CMake ${CMAKE_VER}" \
      curl -L -o "$CMAKE_TGZ" "$CMAKE_URL"

    run_step "Extract CMake ${CMAKE_VER}" \
      tar -xzf "$CMAKE_TGZ"

    rm -f "$CMAKE_TGZ"
  else
    msg "CMake ${CMAKE_VER} already present at $CMAKE_DIR"
  fi

  export PATH="$CMAKE_DIR/bin:$PREFIX/bin:$PATH"
  export CMAKE_PREFIX_PATH="$PREFIX"
  export PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

  msg "Using CMake: $(command -v cmake)"
  cmake --version
}

create_launcher_wrapper() {
  msg "Creating launcher wrapper at $PREFIX/bin/waywallen-local"

  cat > "$PREFIX/bin/waywallen-local" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"

export PATH="$PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$PREFIX/lib64:$PREFIX/lib:${LD_LIBRARY_PATH:-}"
export QML_IMPORT_PATH="$PREFIX/lib64/qt6/qml:$PREFIX/lib/qt6/qml"
export QT_PLUGIN_PATH="$PREFIX/lib64/qt6/plugins:$PREFIX/lib/qt6/plugins"
export XDG_DATA_DIRS="$PREFIX/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

exec "$PREFIX/bin/waywallen" \
  --ui "$PREFIX/bin/waywallen-ui" \
  --plugin "$PREFIX/share/waywallen"
EOF

  chmod +x "$PREFIX/bin/waywallen-local"
}

create_desktop_entry() {
  mkdir -p "$PREFIX/share/applications"

  cat > "$PREFIX/share/applications/waywallen-local.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Waywallen Local
Exec=$PREFIX/bin/waywallen-local
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Graphics;Utility;
EOF
}

do_native_build() {
  mkdir -p "$PREFIX" "$PREFIX/bin" "$PREFIX/share" "$PREFIX/lib"
  mkdir -p "$SRC_DIR" "$BUILD_DIR"

  bootstrap_local_cmake

  clone_or_update https://github.com/waywallen/waywallen-display.git "$SRC_DIR/waywallen-display"
  clone_or_update https://github.com/waywallen/waywallen.git "$SRC_DIR/waywallen"
  clone_or_update https://github.com/waywallen/open-wallpaper-engine.git "$SRC_DIR/open-wallpaper-engine"

  clean_build_dir "$BUILD_DIR/waywallen-display"

  run_step "Configure waywallen-display" \
    cmake -S "$SRC_DIR/waywallen-display" \
          -B "$BUILD_DIR/waywallen-display" \
          -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DCMAKE_C_COMPILER=clang \
          -DCMAKE_CXX_COMPILER=clang++ \
          -DWAYWALLEN_DISPLAY_PLUGIN_QML=ON

  run_step "Build waywallen-display" \
    cmake --build "$BUILD_DIR/waywallen-display" -j"$JOBS"

  run_step "Install waywallen-display" \
    cmake --install "$BUILD_DIR/waywallen-display"

  run_step "Build waywallen daemon" \
    cargo build --release --manifest-path "$SRC_DIR/waywallen/Cargo.toml"

  run_step "Install waywallen daemon" \
    install -Dm755 \
      "$SRC_DIR/waywallen/target/release/waywallen" \
      "$PREFIX/bin/waywallen"

  clean_build_dir "$SRC_DIR/waywallen/build/clang-release"

  run_step "Configure waywallen UI/plugins/bridge" \
    cmake --preset clang-release \
          -S "$SRC_DIR/waywallen" \
          -B "$SRC_DIR/waywallen/build/clang-release" \
          -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DCMAKE_C_COMPILER=clang \
          -DCMAKE_CXX_COMPILER=clang++

  run_step "Build waywallen UI/plugins/bridge" \
    cmake --build "$SRC_DIR/waywallen/build/clang-release" -j"$JOBS"

  run_step "Install waywallen UI/plugins/bridge" \
    cmake --install "$SRC_DIR/waywallen/build/clang-release"

  clean_build_dir "$BUILD_DIR/open-wallpaper-engine"

  local shader_cpp="$SRC_DIR/open-wallpaper-engine/src/Vulkan/Shader.cpp"

  if [[ -f "$shader_cpp" ]] && \
     grep -q '#include <glslang/SPIRV/GlslangToSpv.h>' "$shader_cpp"; then
    run_step "Patch open-wallpaper-engine glslang include" \
      sed -i 's|#include <glslang/SPIRV/GlslangToSpv.h>|#include <SPIRV/GlslangToSpv.h>|' "$shader_cpp"
  else
    msg "open-wallpaper-engine glslang include already patched or not present"
  fi

  run_step "Configure open-wallpaper-engine" \
    cmake -S "$SRC_DIR/open-wallpaper-engine" \
          -B "$BUILD_DIR/open-wallpaper-engine" \
          -G Ninja \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DCMAKE_PREFIX_PATH="$PREFIX" \
          -DCMAKE_C_COMPILER=clang \
          -DCMAKE_CXX_COMPILER=clang++

  run_step "Build open-wallpaper-engine" \
    cmake --build "$BUILD_DIR/open-wallpaper-engine" -j"$JOBS"

  run_step "Install open-wallpaper-engine" \
    cmake --install "$BUILD_DIR/open-wallpaper-engine"

  create_launcher_wrapper
  create_desktop_entry
}

###############################################################################
# KDE plugin (host)
###############################################################################
install_kde_plugin_on_host() {
  if [[ "$INSTALL_KDE_PLUGIN" != "1" ]]; then
    return 0
  fi

  if ! command -v kpackagetool6 >/dev/null 2>&1; then
    warn "Skipping KDE wallpaper package install because kpackagetool6 was not found"
    return 0
  fi

  local kde_package="$SRC_DIR/waywallen-display/extensions/kde/package"
  if [[ ! -d "$kde_package" ]]; then
    warn "KDE wallpaper package not found at: $kde_package"
    warn "Skipping KDE plugin install"
    return 0
  fi

  msg "Installing/updating KDE wallpaper package on host"
  if ! kpackagetool6 --type Plasma/Wallpaper -i "$kde_package"; then
    kpackagetool6 --type Plasma/Wallpaper -u "$kde_package"
  fi
}

###############################################################################
# Flatpak helpers (host only)
###############################################################################
ensure_flatpak_remote() {
  require_cmd flatpak

  run_step "Ensure Flathub remote exists" \
    flatpak remote-add --if-not-exists --user flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
}

ensure_flatpak_builder_available() {
  require_cmd flatpak
  ensure_flatpak_remote

  if flatpak info --user "$FLATPAK_BUILDER_APP_ID" >/dev/null 2>&1; then
    msg "Flatpak Builder already installed"
    return 0
  fi

  run_step "Install Flatpak Builder" \
    flatpak install --user -y flathub "$FLATPAK_BUILDER_APP_ID"
}

prepare_kde_plugin_sources_for_flatpak_mode() {
  if [[ "$INSTALL_KDE_PLUGIN" != "1" ]]; then
    return 0
  fi

  local display_repo="$SRC_DIR/waywallen-display"
  if [[ ! -d "$display_repo/.git" ]]; then
    clone_or_update https://github.com/waywallen/waywallen-display.git "$display_repo"
  elif [[ "$UPDATE_REPOS" == "1" ]]; then
    msg "Updating waywallen-display for KDE plugin resources"
    git -C "$display_repo" pull --ff-only
    if command -v git-lfs >/dev/null 2>&1; then
      git -C "$display_repo" lfs pull || true
    fi
  fi
}

build_and_install_flatpak_on_host() {
  ensure_flatpak_builder_available
  clone_or_update "$FLATPAK_REPO_URL" "$FLATPAK_SRC_DIR"

  [[ -f "$FLATPAK_SRC_DIR/$FLATPAK_MANIFEST" ]] || \
    die "Flatpak manifest not found: $FLATPAK_SRC_DIR/$FLATPAK_MANIFEST"

  mkdir -p "$(dirname "$FLATPAK_BUILD_DIR")"

  run_step "Build and install Flatpak on host" \
    flatpak-builder \
      --user \
      --install \
      --force-clean \
      --install-deps-from=flathub \
      "$FLATPAK_BUILD_DIR" \
      "$FLATPAK_SRC_DIR/$FLATPAK_MANIFEST"
}

###############################################################################
# Main
###############################################################################
msg "Logging to $LOG_FILE"
msg "Configuration:"
msg "  ROOT_DIR=$ROOT_DIR"
msg "  PREFIX=$PREFIX"
msg "  SRC_DIR=$SRC_DIR"
msg "  BUILD_DIR=$BUILD_DIR"
msg "  LOG_DIR=$LOG_DIR"
msg "  JOBS=$JOBS"
msg "  USE_DISTROBOX=$USE_DISTROBOX"
msg "  DISTROBOX_NAME=$DISTROBOX_NAME"
msg "  DISTROBOX_HOME=$DISTROBOX_HOME"
msg "  INSTALL_KDE_PLUGIN=$INSTALL_KDE_PLUGIN"
msg "  UPDATE_REPOS=$UPDATE_REPOS"
msg "  CLEAN_BUILD_DIRS=$CLEAN_BUILD_DIRS"
msg "  BUILD_FLATPAK=$BUILD_FLATPAK"
msg "  FLATPAK_SRC_DIR=$FLATPAK_SRC_DIR"
msg "  FLATPAK_BUILD_DIR=$FLATPAK_BUILD_DIR"
msg "  WAYWALLEN_INNER_RUN=$WAYWALLEN_INNER_RUN"

check_host_tools

if [[ "$BUILD_FLATPAK" == "1" ]]; then
  prepare_kde_plugin_sources_for_flatpak_mode
  build_and_install_flatpak_on_host
  install_kde_plugin_on_host
else
  if [[ "$USE_DISTROBOX" == "1" ]]; then
    ensure_distrobox_host_deps
    print_fedora_44_packages
    create_fedora44_distrobox
    install_distrobox_build_deps
    initialize_git_lfs_in_distrobox
    configure_rust_toolchain_in_distrobox
    verify_git_lfs_in_distrobox

    run_step "Run native installer inside Fedora 44 distrobox" \
      env WAYWALLEN_INNER_RUN=1 LOG_FILE="$LOG_FILE" \
      distrobox enter "$DISTROBOX_NAME" -- bash -lc \
      "cd '$ROOT_DIR' && \
       export WAYWALLEN_INNER_RUN=1 && \
       export LOG_FILE='$LOG_FILE' && \
       export USE_DISTROBOX=0 && \
       export BUILD_FLATPAK=0 && \
       export PREFIX='$PREFIX' && \
       export SRC_DIR='$SRC_DIR' && \
       export BUILD_DIR='$BUILD_DIR' && \
       export LOG_DIR='$LOG_DIR' && \
       export JOBS='$JOBS' && \
       export INSTALL_KDE_PLUGIN=0 && \
       export UPDATE_REPOS='$UPDATE_REPOS' && \
       export CLEAN_BUILD_DIRS='$CLEAN_BUILD_DIRS' && \
       export DISTROBOX_NAME='$DISTROBOX_NAME' && \
       export DISTROBOX_HOME='$DISTROBOX_HOME' && \
       bash '$0' --no-distrobox --no-kde --prefix '$PREFIX' --src-dir '$SRC_DIR' --build-dir '$BUILD_DIR' --jobs '$JOBS' $( [[ '$UPDATE_REPOS' == '0' ]] && printf -- '--no-update' ) $( [[ '$CLEAN_BUILD_DIRS' == '0' ]] && printf -- '--no-clean' )"

    install_kde_plugin_on_host
  else
    if ! check_build_tools || ! check_pkgconfig_modules; then
      warn "Current environment is missing some native build deps."
      warn "The default path is building inside distrobox."
      print_fedora_44_packages
    fi

    do_native_build
    install_kde_plugin_on_host
  fi
fi

###############################################################################
# Summary
###############################################################################
cat <<EOF

Install complete.

Mode:
  $( [[ "$BUILD_FLATPAK" == "1" ]] && echo "Flatpak-only (+ optional KDE plugin)" || echo "Native install (+ optional KDE plugin)" )

Native install prefix:
  $PREFIX

Run native install with:
  $PREFIX/bin/waywallen-local

Native desktop entry:
  $PREFIX/share/applications/waywallen-local.desktop

Log file:
  $LOG_FILE

Useful options:
  --help                 Show help
  --flatpak              Build/install Flatpak only on host
  --no-distrobox         Build native components on the current host
  --no-kde               Skip KDE wallpaper package install
  --no-update            Do not git pull existing repos
  --no-clean             Reuse existing build directories
  --prefix PATH          Install somewhere other than ~/.local

Examples:
  $0
  $0 --flatpak
  $0 --flatpak --no-kde
  $0 --no-distrobox
EOF
