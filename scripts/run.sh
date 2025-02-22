#!/bin/bash
#
# This file is part of MagiskOnWSALocal.
#
# MagiskOnWSALocal is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# MagiskOnWSALocal is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with MagiskOnWSALocal.  If not, see <https://www.gnu.org/licenses/>.
#
# Copyright (C) 2022 LSPosed Contributors
#

# DEBUG=--debug
# CUSTOM_MAGISK=--magisk-custom

if [ ! "$BASH_VERSION" ]; then
    echo "Please do not use sh to run this script, just execute it directly" 1>&2
    exit 1
fi
cd "$(dirname "$0")" || exit 1
SUDO="$(which sudo 2>/dev/null)"
abort() {
    echo "Dependencies: an error has occurred, exit"
    exit 1
}
require_su() {
    if test "$(whoami)" != "root"; then
        if [ -z "$SUDO" ] && [ "$($SUDO whoami)" != "root" ]; then
            echo "ROOT/SUDO is required to run this script"
            abort
        fi
    fi
}
echo "Install lasted kernel"
     pwd
     wget https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
     sudo install ubuntu-mainline-kernel.sh /usr/local/bin/
     ubuntu-mainline-kernel.sh -c
     sudo ubuntu-mainline-kernel.sh -i --yes
     reboot
     echo "Checking kernel..."
     uname -rs
echo "Install lasted kernel done!"

echo "Checking and ensuring dependencies"
check_dependencies() {
    command -v whiptail >/dev/null 2>&1 || command -v dialog >/dev/null 2>&1 || NEED_INSTALL+=("whiptail")
    command -v seinfo >/dev/null 2>&1 || NEED_INSTALL+=("setools")
    command -v lzip >/dev/null 2>&1 || NEED_INSTALL+=("lzip")
    command -v wine64 >/dev/null 2>&1 || NEED_INSTALL+=("wine")
    command -v winetricks >/dev/null 2>&1 || NEED_INSTALL+=("winetricks")
    command -v patchelf >/dev/null 2>&1 || NEED_INSTALL+=("patchelf")
    command -v resize2fs >/dev/null 2>&1 || NEED_INSTALL+=("e2fsprogs")
    command -v pip >/dev/null 2>&1 || NEED_INSTALL+=("python3-pip")
    command -v aria2c >/dev/null 2>&1 || NEED_INSTALL+=("aria2")
    command -v erofs-utils >/dev/null 2>&1 || NEED_INSTALL+=("erofs-utils")
    command -v fuse >/dev/null 2>&1 || NEED_INSTALL+=("fuse")
    command -v 7z > /dev/null 2>&1 || NEED_INSTALL+=("p7zip-full")
    command -v setfattr > /dev/null 2>&1 || NEED_INSTALL+=("attr")
    command -v qemu-img >/dev/null 2>&1 || NEED_INSTALL+=("qemu-utils")
}
check_dependencies
osrel=$(sed -n '/^ID_LIKE=/s/^.*=//p' /etc/os-release);
declare -A os_pm_install;
# os_pm_install["/etc/redhat-release"]=yum
# os_pm_install["/etc/arch-release"]=pacman
# os_pm_install["/etc/gentoo-release"]=emerge
os_pm_install["/etc/SuSE-release"]=zypper
os_pm_install["/etc/debian_version"]=apt-get
# os_pm_install["/etc/alpine-release"]=apk

declare -A PM_UPDATE_MAP;
PM_UPDATE_MAP["yum"]="check-update"
PM_UPDATE_MAP["pacman"]="-Syu --noconfirm"
PM_UPDATE_MAP["emerge"]="-auDN @world"
PM_UPDATE_MAP["zypper"]="ref"
PM_UPDATE_MAP["apt-get"]="update"
PM_UPDATE_MAP["apk"]="update"

declare -A PM_INSTALL_MAP;
PM_INSTALL_MAP["yum"]="install -y"
PM_INSTALL_MAP["pacman"]="-S --noconfirm --needed"
PM_INSTALL_MAP["emerge"]="-a"
PM_INSTALL_MAP["zypper"]="in -y"
PM_INSTALL_MAP["apt-get"]="install -y"
PM_INSTALL_MAP["apk"]="add"

check_package_manager() {
    for f in "${!os_pm_install[@]}"; do
        if [[ -f $f ]]; then
            PM="${os_pm_install[$f]}"
            break
        fi
    done
    if [[ "$osrel" = *"suse"* ]]; then
        PM="zypper"
    fi
    if [ -n "$PM" ]; then
        readarray -td ' ' UPDATE_OPTION <<<"${PM_UPDATE_MAP[$PM]} "; unset 'UPDATE_OPTION[-1]';
        readarray -td ' ' INSTALL_OPTION <<<"${PM_INSTALL_MAP[$PM]} "; unset 'INSTALL_OPTION[-1]';
    fi
}

check_package_manager
if [ -n "${NEED_INSTALL[*]}" ]; then
    if [ -z "$PM" ]; then
        echo "Unable to determine package manager: Unsupported distros"
        abort
    else
        if [ "$PM" = "zypper" ]; then
            NEED_INSTALL_FIX=${NEED_INSTALL[*]}
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//setools/setools-console} >> /dev/null 2>&1
            NEED_INSTALL_FIX=${NEED_INSTALL_FIX//whiptail/dialog} >> /dev/null 2>&1
            readarray -td ' ' NEED_INSTALL <<<"$NEED_INSTALL_FIX "; unset 'NEED_INSTALL[-1]';
        elif [ "$PM" = "apk" ]; then
            NEED_INSTALL_FIX=${NEED_INSTALL[*]}
            readarray -td ' ' NEED_INSTALL <<<"${NEED_INSTALL_FIX//p7zip-full/p7zip} "; unset 'NEED_INSTALL[-1]';
        fi
        require_su
        if ! ($SUDO "$PM" "${UPDATE_OPTION[@]}" && $SUDO "$PM" "${INSTALL_OPTION[@]}" "${NEED_INSTALL[@]}") then abort; fi
    fi
fi
pip list --disable-pip-version-check | grep -E "^requests " >/dev/null 2>&1 || python3 -m pip install requests

winetricks list-installed | grep -E "^msxml6" >/dev/null 2>&1 || {
    cp -r ../wine/.cache/* ~/.cache
    winetricks msxml6 || abort
}
WHIPTAIL=$(command -v whiptail 2>/dev/null)
DIALOG=$(command -v dialog 2>/dev/null)
DIALOG=${WHIPTAIL:-$DIALOG}
function Radiolist {
    declare -A o="$1"
    shift
    if ! $DIALOG --nocancel --radiolist "${o[title]}" 0 0 0 "$@" 3>&1 1>&2 2>&3; then
        echo "${o[default]}"
    fi
}

function YesNoBox {
    declare -A o="$1"
    shift
    $DIALOG --title "${o[title]}" --yesno "${o[text]}" 0 0
}

COMPRESS_OUTPUT="--compress"

declare -A RELEASE_TYPE_MAP=(["retail"]="retail" ["release preview"]="RP" ["insider slow"]="WIS" ["insider fast"]="WIF")

echo "检查GAPPS是否需要"
echo $GAPPS_BRAND
echo $GAPPS_VARIANT
if [ $GAPPS_VARIANT == "none" ]; then
    echo " Gapps is none, Set gapps brand gone!"
    COMMAND_LINE=(--arch "$ARCH" --release-type "${RELEASE_TYPE_MAP[$RELEASE_TYPE]}" --magisk-ver "$MAGISK_VER" --gapps-brand "$GAPPS_BRAND" --gapps-variant "$GAPPS_VARIANT" "$REMOVE_AMAZON" --root-sol "$ROOT_SOL" "$COMPRESS_OUTPUT" "$OFFLINE" "$DEBUG" "$CUSTOM_MAGISK" --debug)
elif [ $GAPPS_VARIANT != "none" ]; then
    COMMAND_LINE=(--arch "$ARCH" --release-type "${RELEASE_TYPE_MAP[$RELEASE_TYPE]}" --magisk-ver "$MAGISK_VER" --gapps-brand "$GAPPS_BRAND" --gapps-variant "$GAPPS_VARIANT" "$REMOVE_AMAZON" --root-sol "$ROOT_SOL" "$COMPRESS_OUTPUT" "$OFFLINE" "$DEBUG" "$CUSTOM_MAGISK" --debug)
fi

echo "命令行检查 COMMAND_LINE=${COMMAND_LINE[*]}"
echo "开始编译！"
./build.sh "${COMMAND_LINE[@]}"
