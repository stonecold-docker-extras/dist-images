#!/usr/bin/env bash

./update-image.sh -d alpine -a x64 -f $@
./update-image.sh -d alpine -a armv7h -f $@
./update-image.sh -d alpine -a aarch64 -f $@
./update-image.sh -d arch -a x64 -f $@
./update-image.sh -d arch -a armv7h -f $@
./update-image.sh -d arch -a aarch64 -f $@
./update-image.sh -d debian -a x64 -f $@
./update-image.sh -d debian -a armv7h -f $@
./update-image.sh -d debian -a aarch64 -f $@
./update-image.sh -d ubuntu -a x64 -f $@
./update-image.sh -d ubuntu -a armv7h -f $@
./update-image.sh -d ubuntu -a aarch64 -f $@

