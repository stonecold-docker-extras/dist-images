#!/usr/bin/env bash

for dist in alpine arch debian ubuntu
do
	for arch in x64 armhf aarch64
	do
		echo "${dist} ${arch}"
		docker pull forumi0721/${dist}-${arch}-base
	done
done

