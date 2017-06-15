#!/usr/bin/env bash

set -e

./update-image-docker.sh -d alpine -a x64 -f -s -i $@
./update-image-docker.sh -d alpine -a armhf -f -s -i $@
./update-image-docker.sh -d alpine -a aarch64 -f -s -i $@
./update-image-docker.sh -d arch -a x64 -f -s -i $@
./update-image-docker.sh -d arch -a armhf -f -s -i $@
./update-image-docker.sh -d arch -a aarch64 -f -s -i $@
./update-image-docker.sh -d debian -a x64 -f -s -i $@
./update-image-docker.sh -d debian -a armhf -f -s -i $@
./update-image-docker.sh -d debian -a aarch64 -f -s -i $@
./update-image-docker.sh -d ubuntu -a x64 -f -s -i $@
./update-image-docker.sh -d ubuntu -a armhf -f -s -i $@
./update-image-docker.sh -d ubuntu -a aarch64 -f -s -i $@

