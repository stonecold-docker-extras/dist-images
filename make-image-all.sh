#!/usr/bin/env bash

for dist in arch entware debian ubuntu alpine
do
	for arch in x64 armhf aarch64
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -m -q -v $@
	done
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-bionic"
		./image.sh -d ubuntu -a x64 -e bionic -m -q -v $@
		echo "${dist} x64-xenial"
		./image.sh -d ubuntu -a x64 -e xenial -m -q -v $@
	fi
done

