#!/usr/bin/env bash

for dist in arch entware debian ubuntu alpine
do
	for arch in x64 armhf aarch64
	do
		echo "${dist} ${arch}"
		docker pull forumi0721/${dist}-${arch}-base
	done
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-bionic"
		docker pull forumi0721/ubnutu-x64-base-bionic
		echo "${dist} x64-xenial"
		docker pull forumi0721/ubnutu-x64-base-xenial
	fi
done

