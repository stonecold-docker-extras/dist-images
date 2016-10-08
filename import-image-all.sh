#!/usr/bin/env bash

./update-s -image.sh -d arch -a x64 -f -s -i $@
./update-s -image.sh -d arch -a armv7h -f -s -i $@
./update-s -image.sh -d alpine -a x64 -f -s -i $@
./update-s -image.sh -d alpine -a armv7h -f -s -i $@
./update-s -image.sh -d debian -a x64 -f -s -i $@
./update-s -image.sh -d debian -a armv7h -f -s -i $@
./update-s -image.sh -d ubuntu -a x64 -f -s -i $@
./update-s -image.sh -d ubuntu -a armv7h -f -s -i $@

