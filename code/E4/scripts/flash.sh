#!/usr/bin/env bash
set -euo pipefail

# Silicon Labs 烧录工具的绝对路径
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
用法：
  $(basename "$0") [-f <firmware.hex|firmware.omf>] [-s serial_no] [-t c2|jtag] [-e full|page|merge]

选项：
  -f  固件文件路径（.hex 或 .omf），可使用相对路径或绝对路径
      省略时默认使用：${DEFAULT_FIRMWARE}
  -s  调试器序列号（默认：${DEFAULT_SN}）
  -t  目标接口（默认：${DEFAULT_TIF}）
  -e  擦除模式（默认：${DEFAULT_ERASEMODE}）
  -l  列出已连接的 8051 设备
  -h  显示帮助信息

示例：
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
    :) echo "错误：-$OPTARG 需要参数" >&2; usage; exit 1 ;;
    \?) echo "错误：无效选项 -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -x "$FLASH_TOOL" ]]; then
  echo "错误：找不到烧录工具或没有执行权限：$FLASH_TOOL" >&2
  exit 1
fi

if [[ ! -x "$DETECT_TOOL" ]]; then
  echo "错误：找不到设备检测工具或没有执行权限：$DETECT_TOOL" >&2
  exit 1
fi

if [[ "$list_only" == "true" ]]; then
  echo "正在列出已连接设备..."
  sudo "$DETECT_TOOL" -slist
  exit 0
fi

if [[ -z "$firmware" ]]; then
  firmware="$DEFAULT_FIRMWARE"
fi

firmware_abs="$(realpath "$firmware")"

if [[ ! -f "$firmware_abs" ]]; then
  echo "错误：固件文件不存在：$firmware_abs" >&2
  exit 1
fi

case "$firmware_abs" in
  *.hex|*.omf) ;;
  *)
    echo "错误：固件必须是 .hex 或 .omf：$firmware_abs" >&2
    exit 1
    ;;
esac

case "$tif" in
  c2|jtag) ;;
  *)
    echo "错误：-t 的值无效：'$tif'，应为 c2 或 jtag" >&2
    exit 1
    ;;
esac

case "$erasemode" in
  full|page|merge) ;;
  *)
    echo "错误：-e 的值无效：'$erasemode'，应为 full/page/merge" >&2
    exit 1
    ;;
esac

echo "准备烧录 C8051F310："
echo "  调试器序列号 : $sn"
echo "  接口         : $tif"
echo "  擦除模式     : $erasemode"
echo "  固件         : $firmware_abs"

echo "开始烧录..."
sudo "$FLASH_TOOL" -sn "$sn" -tif "$tif" -erasemode "$erasemode" -upload "$firmware_abs"
echo "烧录完成。"
