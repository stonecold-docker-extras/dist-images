#!/usr/bin/env bash

./update-image.sh -d arch -a x64 -f -i $@
./update-image.sh -d arch -a armv7h -f -i $@
./update-image.sh -d alpine -a x64 -f -i $@
./update-image.sh -d alpine -a armv7h -f -i $@
./update-image.sh -d debian -a x64 -f -i $@
./update-image.sh -d debian -a armv7h -f -i $@
./update-image.sh -d ubuntu -a x64 -f -i $@
./update-image.sh -d ubuntu -a armv7h -f -i $@

