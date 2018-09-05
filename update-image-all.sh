#!/usr/bin/env bash

for dist in alpine arch debian ubuntu
do
	for arch in x64 armhf aarch64
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -u -q -v $@
	done
done

./image.sh -d ubuntu -a x64 -e xenial -u -q -v $@
#./image.sh -d ubuntu -a x64 -e artful -u -q -v $@

