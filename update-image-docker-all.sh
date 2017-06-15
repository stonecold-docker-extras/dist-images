#!/usr/bin/env bash

./update-image-docker.sh -d alpine -a x64 -f $@
./update-image-docker.sh -d alpine -a armhf -f $@
./update-image-docker.sh -d alpine -a aarch64 -f $@
./update-image-docker.sh -d arch -a x64 -f $@
./update-image-docker.sh -d arch -a armhf -f $@
./update-image-docker.sh -d arch -a aarch64 -f $@
./update-image-docker.sh -d debian -a x64 -f $@
./update-image-docker.sh -d debian -a armhf -f $@
./update-image-docker.sh -d debian -a aarch64 -f $@
./update-image-docker.sh -d ubuntu -a x64 -f $@
./update-image-docker.sh -d ubuntu -a armhf -f $@
./update-image-docker.sh -d ubuntu -a aarch64 -f $@

