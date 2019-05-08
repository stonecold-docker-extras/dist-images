#!/usr/bin/env bash

for dist in debian ubuntu alpine entware
do
	for arch in x64 aarch64 armhf
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -m -q -v $@
	done
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-bionic"
		./image.sh -d ubuntu -a x64 -e bionic -m -q -v $@
	fi
done

