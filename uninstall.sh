#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# Defaults / Config
###############################################################################
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"

# Default mode: host uninstall
UNINSTALL_HOST="${UNINSTALL_HOST:-1}"
UNINSTALL_FLATPAK="${UNINSTALL_FLATPAK:-0}"
REMOVE_KDE_PLUGIN="${REMOVE_KDE_PLUGIN:-1}"

FLATPAK_APP_ID="${FLATPAK_APP_ID:-org.waywallen.waywallen}"

###############################################################################
# Logging
###############################################################################
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/uninstall-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

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

###############################################################################
# Help / CLI
###############################################################################
show_help() {
cat <<EOF
Waywallen uninstaller

Usage:
  $0 [options]

Modes:
  --host                 Remove native ~/.local install (default)
  --flatpak              Remove Flatpak install
  --host --flatpak       Remove both

Options:
  -h, --help             Show this help message
  --host                 Uninstall native host install
  --flatpak              Uninstall Flatpak install
  --no-kde               Do not remove KDE wallpaper plugin
  --prefix PATH          Install prefix to remove (default: $PREFIX)
  --flatpak-app-id ID    Flatpak app id (default: $FLATPAK_APP_ID)

Examples:
  $0
  $0 --flatpak
  $0 --host --flatpak
  $0 --flatpak --no-kde
EOF
}

# If either mode is specified explicitly, stop using the default implicit host mode.
MODE_EXPLICIT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --host)
      if [[ "$MODE_EXPLICIT" == "0" ]]; then
        UNINSTALL_HOST=0
        UNINSTALL_FLATPAK=0
        MODE_EXPLICIT=1
      fi
      UNINSTALL_HOST=1
      shift
      ;;
    --flatpak)
      if [[ "$MODE_EXPLICIT" == "0" ]]; then
        UNINSTALL_HOST=0
        UNINSTALL_FLATPAK=0
        MODE_EXPLICIT=1
      fi
      UNINSTALL_FLATPAK=1
      shift
      ;;
    --no-kde)
      REMOVE_KDE_PLUGIN=0
      shift
      ;;
    --prefix)
      [[ $# -ge 2 ]] || die "--prefix requires a value"
      PREFIX="$2"
      shift 2
      ;;
    --flatpak-app-id)
      [[ $# -ge 2 ]] || die "--flatpak-app-id requires a value"
      FLATPAK_APP_ID="$2"
      shift 2
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

if [[ "$UNINSTALL_HOST" != "1" && "$UNINSTALL_FLATPAK" != "1" ]]; then
  die "Nothing selected to uninstall. Use --host, --flatpak, or both."
fi

###############################################################################
# Helpers
###############################################################################
remove_if_exists() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    msg "Removing $path"
    rm -rf "$path"
  else
    msg "Not present, skipping: $path"
  fi
}

remove_kde_plugin() {
  if [[ "$REMOVE_KDE_PLUGIN" != "1" ]]; then
    return 0
  fi

  if ! command -v kpackagetool6 >/dev/null 2>&1; then
    warn "kpackagetool6 not found; skipping KDE wallpaper plugin removal"
    return 0
  fi

  local ids=(
    "org.waywallen.Waywallen"
    "org.waywallen.waywallen"
    "waywallen"
  )

  local removed=0
  for id in "${ids[@]}"; do
    if kpackagetool6 --type Plasma/Wallpaper -r "$id" >/dev/null 2>&1; then
      msg "Removed KDE wallpaper plugin: $id"
      removed=1
      break
    fi
  done

  if [[ "$removed" == "0" ]]; then
    warn "Could not confirm KDE wallpaper plugin removal by package id; it may already be absent"
  fi
}

uninstall_host() {
  msg "Removing native host install from $PREFIX"

  remove_if_exists "$PREFIX/bin/waywallen"
  remove_if_exists "$PREFIX/bin/waywallen-ui"
  remove_if_exists "$PREFIX/bin/waywallen-wescene-renderer"
  remove_if_exists "$PREFIX/bin/waywallen-mpv-renderer"
  remove_if_exists "$PREFIX/bin/waywallen-image-renderer"
  remove_if_exists "$PREFIX/bin/waywallen-local"

  remove_if_exists "$PREFIX/share/applications/waywallen-local.desktop"
  remove_if_exists "$PREFIX/share/waywallen"

  remove_if_exists "$PREFIX/lib64/qt6/qml/Waywallen/Display"
  remove_if_exists "$PREFIX/lib64/qt6/qml/Waywallen"
  remove_if_exists "$PREFIX/lib/qt6/qml/Waywallen/Display"
  remove_if_exists "$PREFIX/lib/qt6/qml/Waywallen"

  remove_if_exists "$PREFIX/lib64/libwaywallen_display.so"
  remove_if_exists "$PREFIX/lib64/libwaywallen_display.so.0"
  remove_if_exists "$PREFIX/lib64/libwaywallen_display.so.0.1.0"
  remove_if_exists "$PREFIX/lib64/libwaywallen_display.a"

  remove_if_exists "$PREFIX/lib/libwaywallen_display.so"
  remove_if_exists "$PREFIX/lib/libwaywallen_display.so.0"
  remove_if_exists "$PREFIX/lib/libwaywallen_display.so.0.1.0"
  remove_if_exists "$PREFIX/lib/libwaywallen_display.a"

  remove_if_exists "$PREFIX/lib/libspirv-reflect-static.a"
  remove_if_exists "$PREFIX/lib64/libspirv-reflect-static.a"

  remove_if_exists "$PREFIX/include/waywallen_display.h"
  remove_if_exists "$PREFIX/include/waywallen-bridge"

  remove_kde_plugin
}

uninstall_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    warn "flatpak not found; skipping Flatpak removal"
    remove_kde_plugin
    return 0
  fi

  if flatpak info --user "$FLATPAK_APP_ID" >/dev/null 2>&1; then
    run_step "Uninstall Flatpak $FLATPAK_APP_ID" \
      flatpak uninstall --user -y "$FLATPAK_APP_ID"
  else
    msg "Flatpak not installed for user, skipping: $FLATPAK_APP_ID"
  fi

  remove_kde_plugin
}

###############################################################################
# Main
###############################################################################
msg "Logging to $LOG_FILE"
msg "Configuration:"
msg "  PREFIX=$PREFIX"
msg "  UNINSTALL_HOST=$UNINSTALL_HOST"
msg "  UNINSTALL_FLATPAK=$UNINSTALL_FLATPAK"
msg "  REMOVE_KDE_PLUGIN=$REMOVE_KDE_PLUGIN"
msg "  FLATPAK_APP_ID=$FLATPAK_APP_ID"

if [[ "$UNINSTALL_HOST" == "1" ]]; then
  uninstall_host
fi

if [[ "$UNINSTALL_FLATPAK" == "1" ]]; then
  uninstall_flatpak
fi

cat <<EOF

Uninstall complete.

Log file:
  $LOG_FILE

Examples:
  $0
  $0 --flatpak
  $0 --host --flatpak
EOF
