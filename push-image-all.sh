#!/usr/bin/env bash

for dist in alpine arch debian ubuntu
do
	for arch in x64 armhf aarch64
	do
		echo "${dist} ${arch}"
		./image.sh -d "${dist}" -a "${arch}" -p -q -v $@
	done
done

./image.sh -d ubuntu -a x64 -n forumi0271/ubuntu-x64-base:xenial -p -q -v $@
