#!/usr/bin/env bash

for dist in debian ubuntu alpine entware
do
	for arch in x64 aarch64
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -i -q -v $@
	done
	if [ "${dist}" = "debian" ]; then
		echo "${dist} x64-stable"
		./image.sh -d debian -a x64 -e stable -i -q -v $@
	fi
	if [ "${dist}" = "ubuntu" ]; then
		echo "${dist} x64-focal"
		./image.sh -d ubuntu -a x64 -e focal -i -q -v $@
		echo "${dist} x64-bionic"
		./image.sh -d ubuntu -a x64 -e bionic -i -q -v $@
		echo "${dist} x64-xenial"
		./image.sh -d ubuntu -a x64 -e xenial -i -q -v $@
	fi
done

