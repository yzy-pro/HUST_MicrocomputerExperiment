#!/usr/bin/env bash
set -euo pipefail

# Absolute paths to Silicon Labs flash tools in this repo.
TOOL_ROOT="/home/yzy/code/MicrocomputerExperiment/tools/siliconlabs-c8051-efm8-utils"
FLASH_TOOL="${TOOL_ROOT}/c8051/flash8051"
DETECT_TOOL="${TOOL_ROOT}/inspect_c8051/device8051"

DEFAULT_SN="EC320126621"
DEFAULT_TIF="c2"
DEFAULT_ERASEMODE="full"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_FIRMWARE="${ROOT}/build/Debug/c8051f310.hex"

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [-f <firmware.hex|firmware.omf>] [-s serial_no] [-t c2|jtag] [-e full|page|merge]

Options:
  -f  Firmware file path (.hex or .omf), can be relative or absolute
      If omitted, default is: ${DEFAULT_FIRMWARE}
  -s  Debug adapter serial number (default: ${DEFAULT_SN})
  -t  Target interface (default: ${DEFAULT_TIF})
  -e  Erase mode (default: ${DEFAULT_ERASEMODE})
  -l  List connected 8051 devices
  -h  Show this help

Example:
  $(basename "$0")
  $(basename "$0") -f ./build/Debug/c8051f310.hex
  $(basename "$0") -f /tmp/app.omf -s EC320126621 -t c2 -e full
USAGE
}

firmware=""
sn="${DEFAULT_SN}"
tif="${DEFAULT_TIF}"
erasemode="${DEFAULT_ERASEMODE}"
list_only="false"

while getopts ":f:s:t:e:lh" opt; do
  case "$opt" in
    f) firmware="$OPTARG" ;;
    s) sn="$OPTARG" ;;
    t) tif="$OPTARG" ;;
    e) erasemode="$OPTARG" ;;
    l) list_only="true" ;;
    h)
      usage
      exit 0
      ;;
    :) echo "Error: -$OPTARG requires an argument" >&2; usage; exit 1 ;;
    \?) echo "Error: invalid option -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -x "$FLASH_TOOL" ]]; then
  echo "Error: flash tool not found or not executable: $FLASH_TOOL" >&2
  exit 1
fi

if [[ ! -x "$DETECT_TOOL" ]]; then
  echo "Error: device detect tool not found or not executable: $DETECT_TOOL" >&2
  exit 1
fi

if [[ "$list_only" == "true" ]]; then
  echo "Listing connected devices..."
  sudo "$DETECT_TOOL" -slist
  exit 0
fi

if [[ -z "$firmware" ]]; then
  firmware="$DEFAULT_FIRMWARE"
fi

firmware_abs="$(realpath "$firmware")"

if [[ ! -f "$firmware_abs" ]]; then
  echo "Error: firmware file does not exist: $firmware_abs" >&2
  exit 1
fi

case "$firmware_abs" in
  *.hex|*.omf) ;;
  *)
    echo "Error: firmware must be .hex or .omf: $firmware_abs" >&2
    exit 1
    ;;
esac

case "$tif" in
  c2|jtag) ;;
  *)
    echo "Error: invalid -t value '$tif', expected c2 or jtag" >&2
    exit 1
    ;;
esac

case "$erasemode" in
  full|page|merge) ;;
  *)
    echo "Error: invalid -e value '$erasemode', expected full/page/merge" >&2
    exit 1
    ;;
esac

echo "Flashing C8051F310 with:"
echo "  SerialNo   : $sn"
echo "  Interface  : $tif"
echo "  EraseMode  : $erasemode"
echo "  Firmware   : $firmware_abs"

echo "Start programming..."
sudo "$FLASH_TOOL" -sn "$sn" -tif "$tif" -erasemode "$erasemode" -upload "$firmware_abs"
echo "Done."
