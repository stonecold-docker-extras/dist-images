#!/bin/sh

if [ "${EUID}" != "0" ]; then
	sudo "${0}" "${@}"
	exit $?
fi

if [ ! -e dist.img ]; then
	truncate -s 5G dist.img
	losetup -f ./dist.img
	lo_dev="$(losetup -j ./dist.img | cut -d ':' -f 1)"
	mkfs.ext4 -F ${lo_dev}
	losetup -d ${lo_dev}
	mount -o loop dist.img dist
	touch dist/img
	umount dist
fi
