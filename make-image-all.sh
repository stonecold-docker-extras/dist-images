#!/usr/bin/env bash

set -e

./image-make.sh -d arch -a x64 -f
./image-make.sh -d arch -a armv7h -f
./image-make.sh -d alpine -a x64 -f
./image-make.sh -d alpine -a armv7h -f
./image-make.sh -d debian -a x64 -f
./image-make.sh -d debian -a armv7h -f
./image-make.sh -d ubuntu -a x64 -f
./image-make.sh -d ubuntu -a armv7h -f

