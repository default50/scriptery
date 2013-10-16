#!/bin/bash

# fs-builder.sh is a utility which should ease building FreeSWITCH Debian
# packages.
# Loosely based on http://wiki.freeswitch.org/wiki/Debianbuild2 and 
# https://github.com/traviscross/freeswitch-sounds/blob/master/debian/README.source
# 
# Copyright (C) 2013 Sebastian Cruz <default50@gmail.com>
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.


BUILDDIR=~/freeswitch-build
BRANCH=v1.2.stable
DISTRO=`lsb_release -cs`
DCH_DISTRO=UNRELEASED

# Install required dependencies
install_deps() {
	PKGS="autoconf automake devscripts gawk g++ git-core libjpeg-dev libncurses5-dev libtool make python-dev gawk pkg-config libtiff4-dev libperl-dev libgdbm-dev libdb-dev gettext sudo equivs mlocate git dpkg-dev devscripts sudo wget sox flac"
	sudo bash -c "apt-get -y update && apt-get -y install $PKGS && apt-get -y -f install && update-alternatives --set awk /usr/bin/gawk"
}

from_scratch() {
	echo "=== Removing $BUILDDIR to start from scratch as requested! ==="
	[ -d $BUILDDIR ] && rm -Rf $BUILDDIR
}

init() {
	# Create $BUILDDIR if not existing
	[ ! -d $BUILDDIR ] && mkdir $BUILDDIR 
	
	# Redirect stdout ( > ) into a named pipe ( >() ) running "tee", then add stderr to stdout
	exec > >(tee $BUILDDIR/build.log)
	exec 2>&1
}

setup_latest() {
	local URL="http://git.freeswitch.org/git/freeswitch/plain/configure.in?h=v1.2.stable"
	local string=$(curl -s ${URL} | grep '^AC_INIT')
	string=(${string//[[\],]})
	VERSION="${string[1]}"
}

buildFS() {
	echo "=== Building FreeSWITCH v$VERSION! ==="
	# If $BUILDDIR/freeswitch doesn't exist assume it needs to be cloned first
	[ ! -d $BUILDDIR/freeswitch ] && (cd $BUILDDIR && git clone -b $BRANCH git://git.freeswitch.org/freeswitch.git)

	# Build
	cd $BUILDDIR/freeswitch
	git clean -fdx
	git pull
	git reset --hard refs/tags/v${VERSION}
	./build/set-fs-version.sh "$FS_VERSION"
	git add configure.in && git commit -m "bump to custom v$FS_VERSION"
	if [ -f modules.conf ]; then cp modules.conf ./debian/; fi
	sed -i '/  formats\/mod_shout/d' ./debian/bootstrap.sh # This is to enable building mod-shout
	(cd debian && ./bootstrap.sh -c ${DISTRO})
	dch -b -m -v "$FS_VERSION" --force-distribution -D "$DCH_DISTRO" "Custom build."
	dpkg-buildpackage -b -us -uc -Zxz -z9
	git reset --hard origin/master

	mkdir ../freeswitch-debs-$FS_VERSION
	mv *$FS_VERSION* ../freeswitch-debs-$FS_VERSION/
}

# Dowload and build sounds
build_sounds() {
	SND_DIR="freeswitch-sounds"

	echo "=== Building FreeSWITCH sound packages! ==="
	[ -d $BUILDDIR/$SND_DIR ] && rm -Rf $BUILDDIR/$SND_DIR

	cd $BUILDDIR
	git clone https://github.com/traviscross/freeswitch-sounds.git $SND_DIR

	cd $SND_DIR
	./debian/bootstrap.sh -p freeswitch-sounds-en-us-callie
	./debian/rules get-orig-source
	tar -xv --strip-components=1 -f *_*.orig.tar.xz && mv *_*.orig.tar.xz ../
	dpkg-buildpackage -b -us -uc -Zxz -z9

	SND_VER=$(ls ../freeswitch-sounds-en-us-callie*.deb | cut -d_ -f2)

	# Create debs dir if not existing
	[ ! -d ../../freeswitch-sounds-debs_${SND_VER} ] && mkdir ../../freeswitch-sounds-debs_${SND_VER}

	mv ../freeswitch-sounds-en-us-callie_${SND_VER}_* ../../freeswitch-sounds-debs_${SND_VER}/
	cd .. && rm -Rf $SND_DIR*
}

build_music() {
	MUSIC_DIR="freeswitch-music"

	echo "=== Building FreeSWITCH music packages! ==="
	[ -d $BUILDDIR/$MUSIC_DIR ] && rm -Rf $BUILDDIR/$MUSIC_DIR

	cd $BUILDDIR
	git clone https://github.com/traviscross/freeswitch-sounds.git $MUSIC_DIR

	cd $MUSIC_DIR
	./debian/bootstrap.sh -p freeswitch-music-default
	./debian/rules get-orig-source
	tar -xv --strip-components=1 -f *_*.orig.tar.xz && mv *_*.orig.tar.xz ../
	dpkg-buildpackage -b -us -uc -Zxz -z9

	MUSIC_VER=$(ls ../freeswitch-music-default*.deb | cut -d_ -f2)
	# Create debs dir if not existing
	[ ! -d ../../freeswitch-music-default-debs_${MUSIC_VER} ] && mkdir ../../freeswitch-music-default-debs_${MUSIC_VER}
	mv ../freeswitch-music-default_${MUSIC_VER}_* ../../freeswitch-music-default-debs_${MUSIC_VER}/
	cd .. && rm -Rf $MUSIC_DIR
}

usage() { echo "Usage: $0 [-dx] [ -v version|\"latest\" -b | -s | -m ] run" 1>&2; exit 1; }

while getopts ":dxbsmv:" opt; do
    case "${opt}" in
        d)
            DEPS="true"
            ;;
        x)
            SCRATCH="true"
            ;;
        b)
            BUILD="true"
            ;;
        s)
            SOUNDS="true"
            ;;
        m)
            MUSIC="true"
            ;;
        v)
            VERSION=${OPTARG}
            if [ x$VERSION == x"latest" ]; then
                setup_latest
                FS_VERSION="$(echo $VERSION | sed -e 's/-/~/g')~n$(date +%Y%m%dT%H%M%SZ)-1~${DISTRO}+1"
            else
                FS_VERSION="$(echo $VERSION | sed -e 's/-/~/g')~n$(date +%Y%m%dT%H%M%SZ)-1~${DISTRO}+1"
            fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# Do nothing if not told explicitly to do so
if [ x${1} != x"run" ]; then
	usage
else
	init

	# Install build dependencies
	[ x$DEPS == x"true" ] && install_deps

	# Start from scratch
	[ x$SCRATCH == x"true" ] && from_scratch

	# Build FreeSWITCH
	[ x$BUILD != x"true" ] || [ -z ${VERSION+x} ] && echo "ERROR: \"-v <version>\" and \"-b\" parameters should be stated together!" && usage || buildFS

	# Build sounds packages
	[ x$SOUNDS == x"true" ] && build_sounds

	# Build music packages
	[ x$MUSIC == x"true" ] && build_music

	[ -z ${BUILD+x} ] && [ -z ${SOUNDS+x} ] && [ -z ${MUSIC+x} ] && echo "ERROR: \"-b\" or \"-s\" or \"-m\" is a required parameter!" && usage
fi
