#!/usr/bin/env bash

./make-image.sh -d alpine -a x64 -f $@
./make-image.sh -d alpine -a armhf -f $@
#./make-image.sh -d alpine -a aarch64 -f $@
./make-image.sh -d arch -a x64 -f $@
./make-image.sh -d arch -a armhf -f $@
#./make-image.sh -d arch -a aarch64 -f $@
./make-image.sh -d debian -a x64 -f $@
./make-image.sh -d debian -a armhf -f $@
#./make-image.sh -d debian -a aarch64 -f $@
./make-image.sh -d ubuntu -a x64 -f $@
./make-image.sh -d ubuntu -a armhf -f $@
#./make-image.sh -d ubuntu -a aarch64 -f $@

