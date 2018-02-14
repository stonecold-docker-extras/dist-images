### Docker hub arm build guide
----------------------------------------

## File description
* README.md
	: This file (README)
* qemu-arm-static
	: arm emulation (patched with execve)
* docker-build-arm
	: Docker Change file
* docker-build-arm.go
	: docker-build-arm source
* Dockerfile
	: Sample docker file

----------------------------------------

## How it use
* Create or download baremetal source to target directory
  Debian : use debootstrap or download image
  Arch : use pacstrap or download image

* Add files to target directory
  docker-build-arm : copy to ${TARGET_DIR}/usr/local/bin/ and link to docker-build-start and docker-build-end

* Write Dockerfile
  Dockerfile : please refer sample file
