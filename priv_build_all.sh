#!/usr/bin/env bash

for d in docker-arch-x64-dev docker-arch-armv7h-dev docker-debian-x64-dev docker-debian-armv7h-dev docker-ubuntu-x64-dev docker-ubuntu-armv7h-dev
do
	if [ -e "${d}" ]; then
		pushd . &> /dev/null
		cd ${d}
		#docker build --no-cache -t forumi0721/${d/docker-/}:latest .
		#docker build -t forumi0721/${d/docker-/}:latest .
		dockercmd build
		popd &> /dev/null
	fi
done
