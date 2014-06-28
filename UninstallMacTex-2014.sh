#!/bin/bash
# File Name:    UninstallMacTeX.command
# Version=1.0
# Author:       Arturo Rinaldi based on the work of toggtc
# Created:      06/25/2014
# Homepage:     https://github.com/toggtc/mactex-uninstaller
#
# WARNING:      This script will remove all files and folders created by MacTex-2014.
#               And if MacTex-2014 and other TeX exist, this script will not work well.
#
# ChangeLog:    1.0 - Tweaked for MacTeX 2014
#
# TODO:         test;)
#-------------------------------
# Variable Initializations
#-------------------------------
OLDIFS=${IFS}
IFS=$'\n'

MACTEX_GUI='org.tug.mactex.gui2014'
MACTEX_TEXLIVE='org.tug.mactex.texlive2014'
MACTEX_GHOSTSCRIPT='org.tug.mactex.ghostscript9.10'
MACTEX_IMAGEMAGICK_CONVERT='org.tug.mactex.imagemagick-convert-6.8.9-1'
MACTEX_LATIN_MODERN='org.tug.mactex.latin-modern'
MACTEX_TEX_GYRE='org.tug.mactex.tex-gyre'

PKGS=`sudo pkgutil --pkgs | grep org.tug.mactex`
PKGS2=`sudo pkgutil --pkgs | grep com.tug.mactex`
VOLUME=`echo ${PKGS} | xargs sudo /usr/sbin/pkgutil --file-info | grep volume | xargs -I{} expr "{}" : "^volume: \(.*.\)"`
VOLUME_APP=`ls /Volumes/ | grep -i [M]acintosh | sed 's/ /\\ /g'`


# for debug
IS_DEBUG=0; [ -f "./.__DEBUG_FILE__" ] && IS_DEBUG=1
IS_REMOVE_OFF=0; [ -f "./.__OFF_REMOVE_FILE__" -o "`echo $@ | grep -e '--no-remove' -e '-n'`" != "" ] && IS_REMOVE_OFF=1;
#-------------------------------
# Function Declarations
#-------------------------------
# For debug logging
_DEBUG()
{
    [ ${IS_DEBUG} -ne 1 -o $# -eq 0 ] && return 1
    echo "`date '+%Y-%m-%d %H:%M:%S'` [DEBUG] $@"
}

# Remove an item.
# $1 file
remove_item()
{
    _DEBUG "remove_item) called, ${1}"
    [ $# -eq 0 ] && return 1
    if [ ${IS_REMOVE_OFF} -eq 1 ];then
        echo "sudo rm -rf ${1}"
    else
        sudo rm -rf ${1}
    fi
}

remove_dir_if_empty()
{
    _DEBUG "remove_dir_if_empty) called, ${1}"
    [ $# -eq 0 ] && return 1
    [ ! -d "${1}" ] && return 1
    is_empty=1
    for f in `find ${1} | sort -r`; do
        if [ -d "${f}" ] && [ -z "$(ls -A ${f})" ]; then
            if [ ${IS_REMOVE_OFF} -eq 1 ];then
                echo "sudo rm -rf ${f}"
            else
                sudo rm -rf ${f}
            fi
        else
            _DEBUG "${f} is not empty."
            is_empty=0
        fi
    done

    if [ ${is_empty} -eq 1 ]; then
        return 0
    else
        return 1
    fi
}
# Do `sudo pkgutil --forget`
# $1 package-id
forget()
{
    [ $# -ne 0 ] || return 1
    if [ ${IS_REMOVE_OFF} -eq 1 ];then
        echo "sudo pkgutil --forget ${1}"
    else
        sudo pkgutil --forget ${1} >/dev/null 2>&1
    fi
}

#
# For GUI Applications
#

# Remove an application.
# $1 application-path (full-path)
remove_app()
{
    _DEBUG "remove_app) called, ${1}"
    # remove the application related files.
    # convert Info.plist to xml format for getting the bundle id.
    if [ "`/usr/bin/plutil -lint ${1}/Contents/Info.plist` | grep 'OK'" != "" ]; then
        `plutil -convert xml1 ${1}/Contents/Info.plist`
        _DEBUG "remove_app) converted ${1}/Contents/Info.plist"
    fi
    appname="`expr ${1} : ".*/\(.*.\)\.app$"`"
    str="`cat ${1}/Contents/Info.plist | grep -n -A 1 CFBundleIdentifier | grep /string`"
    bundleid="`expr ${str} : ".*.string>\(.*.\)<\/string*."`"
    _DEBUG "remove_app) appname =${appname}"
    _DEBUG "remove_app) eundleid=${bundleid}"
    for f in `find ~/Library \( -iname "*${appname}*" -o -iname "*${bundleid}*" \)`
    do
        remove_item ${f}
    done

    remove_item ${1}
}

# Remove all TeX applications.
remove_apps()
{
    _DEBUG "remove_apps) called"
    applist="`find /${VOLUME_APP}/Applications/TeX -name '*.app' -prune`"
    for app in ${applist}; do
        remove_app ${app}
    done
    remove_item "/${VOLUME_APP}/Applications/TeX"
}

#
# For Ghostscript, ImageMagick-convert
#

# Remove files using package-id.
# $1 package-id
remove_with_packageid()
{
    _DEBUG "pid=${1}"
    for f in `sudo /usr/sbin/pkgutil --files ${1}`; do
        if [ -f "${VOLUME}${f}" ]; then
            remove_item "${VOLUME}${f}"
        fi
    done
}

#-------------------------------
# Main
#-------------------------------
#
# Test di modifica per disinstallazione applicazioni Mactex
#
# echo "Remove GUI Applications..."
# applist="`find ${VOLUME}/Applications/TeX -name '*.app' -prune`"
# for app in ${applist}; do
#     remove_app ${app}
# done
# remove_item "${VOLUME}/Applications/TeX"
# echo "Done"

is_already=1
if [ ! -z "`echo ${PKGS} | grep ${MACTEX_GUI}`" ]; then
    echo "Remove GUI Applications..."
    remove_apps
    forget ${MACTEX_GUI}
    is_already=0
    echo "Done"
fi

if [ ! -z "`echo ${PKGS} | grep ${MACTEX_TEXLIVE}`" ]; then
    echo "Remove TeXLive 2014..."
    remove_item "${VOLUME}usr/local/texlive/2014"
    remove_dir_if_empty "/usr/local/texlive"
    if [ ${#} -eq 2 ]; then
        echo "WARNING: Removed texlive-2014, but other version of TeX exist."
        echo "         Please change other version of TeX using TeX Distributions pane in System Preferences."
    else
        remove_item "${VOLUME}usr/texbin"
        remove_item "${VOLUME}usr/local/bin/texdist"
        remove_item "${VOLUME}etc/paths.d/TeX"
        remove_item "${VOLUME}etc/manpaths.d/TeX"
        remove_item "${VOLUME}Library/TeX"
        remove_item "${VOLUME}Library/PreferencePanes/TeXDistPrefPane.prefPane"
    fi

    forget ${MACTEX_TEXLIVE}
    is_already=0
    echo "Done"
fi

if [ ! -z "`echo ${PKGS} | grep ${MACTEX_GHOSTSCRIPT}`" ]; then
    echo "Remove Ghostscript..."
    remove_with_packageid ${MACTEX_GHOSTSCRIPT}
    remove_item "${VOLUME}usr/local/share/ghostscript/9.10"
    remove_dir_if_empty "${VOLUME}usr/local/share/ghostscript"
    forget ${MACTEX_GHOSTSCRIPT}
    is_already=0
    echo "Done"
fi

if [ ! -z "`echo ${PKGS} | grep ${MACTEX_IMAGEMAGICK_CONVERT}`" ]; then
    echo "Remove ImageMagick-convert..."
    remove_with_packageid ${MACTEX_IMAGEMAGICK_CONVERT}
    remove_item "${VOLUME}usr/local/lib/ImageMagick-6.8.9"
    # remove_dir_if_empty "${VOLUME}usr/local/lib/ImageMagick-6.8.9"
    forget ${MACTEX_IMAGEMAGICK_CONVERT}
    is_already=0
    echo "Done"
fi

if [ ! -z "`echo ${PKGS} | grep ${MACTEX_LATIN_MODERN}`" ]; then
    echo "Remove MacTeX Latin-Modern Fonts..."
    remove_with_packageid ${MACTEX_LATIN_MODERN}
    remove_dir_if_empty "${VOLUME}Library/Fonts/Latin\ Modern"
    forget ${MACTEX_LATIN_MODERN}
    is_already=0
    echo "Done"
fi

if [ ! -z "`echo ${PKGS} | grep ${MACTEX_TEX_GYRE}`" ]; then
    echo "Remove MacTeX TeX-Gyre Fonts..."
    remove_with_packageid ${MACTEX_TEX_GYRE}
    remove_dir_if_empty "${VOLUME}Library/Fonts/TeX Gyre"
    forget ${MACTEX_TEX_GYRE}
    is_already=0
    echo "Done"
fi

if [ ${is_already} -eq 1 ]; then
    echo "MacTeX-2014 not found."
else
    echo "Uninstallation of MacTeX 2014 Complete !"
fi
IFS=${OLDIFS}

