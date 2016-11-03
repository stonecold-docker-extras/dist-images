#!/usr/bin/env bash

set -e

docker pull forumi0721/alpine-x64-base
docker pull forumi0721/alpine-armv7h-base
docker pull forumi0721/arch-x64-base
docker pull forumi0721/arch-armv7h-base
docker pull forumi0721/debian-x64-base
docker pull forumi0721/debian-armv7h-base
docker pull forumi0721/ubuntu-x64-base
docker pull forumi0721/ubuntu-armv7h-base

docker pull forumi0721/alpine-x64-dev
docker pull forumi0721/alpine-armv7h-dev
docker pull forumi0721/arch-x64-dev
docker pull forumi0721/arch-armv7h-dev
docker pull forumi0721/debian-x64-dev
docker pull forumi0721/debian-armv7h-dev
docker pull forumi0721/ubuntu-x64-dev
docker pull forumi0721/ubuntu-armv7h-dev

