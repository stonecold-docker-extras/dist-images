#!/usr/bin/env bash

set -e

./make-image.sh -d alpine -a x64 -f $@
./make-image.sh -d alpine -a armv7h -f $@
./make-image.sh -d arch -a x64 -f $@
./make-image.sh -d arch -a armv7h -f $@
./make-image.sh -d debian -a x64 -f $@
./make-image.sh -d debian -a armv7h -f $@
./make-image.sh -d ubuntu -a x64 -f $@
./make-image.sh -d ubuntu -a armv7h -f $@
