#!/usr/bin/env bash

for dist in debian ubuntu alpine entware
do
	for arch in x64 aarch64 armhf
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -m -q -v $@
	done
	if [ "${dist}" = "debian" ]; then
		echo "${dist} x64-stable"
		./image.sh -d debian -a x64 -e stable -m -q -v $@
	fi
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-bionic"
		./image.sh -d ubuntu -a x64 -e bionic -m -q -v $@
	fi
done

