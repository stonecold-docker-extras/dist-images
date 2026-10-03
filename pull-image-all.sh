#!/usr/bin/env bash

for dist in debian ubuntu alpine entware
do
	for arch in x64 aarch64
	do
		echo "${dist} ${arch}"
		docker pull forumi0721/${dist}-${arch}-base
	done
	if [ "${dist}" = "debian" ]; then
		echo "${dist} x64-stable"
		docker pull forumi0721/ubnutu-x64-base-stable
	fi
	if [ "${dist}" = "ubuntu" ]; then
		for x in resolute noble jammy focal bionic xenial
		do
			echo "${dist} x64-${x}"
			docker pull forumi0721/ubuntu-x64-base-${x}
		done
	fi
done

