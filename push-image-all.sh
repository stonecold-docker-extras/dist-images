#!/usr/bin/env bash

for dist in debian ubuntu alpine entware
do
	for arch in x64 aarch64
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -p -q -v $@
	done
	if [ "${dist}" = "debian" ]; then
		echo "${dist} x64-stable"
		./image.sh -d debian -a x64 -e stable -p -q -v $@
	fi
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-focal"
		./image.sh -d ubuntu -a x64 -e focal -p -q -v $@
		echo "${dist} x64-bionic"
		./image.sh -d ubuntu -a x64 -e bionic -p -q -v $@
		echo "${dist} x64-xenial"
		./image.sh -d ubuntu -a x64 -e xenial -p -q -v $@
	fi
done

