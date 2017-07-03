#!/usr/bin/env bash

LANG="C"
LC_ALL="C"

if [ "$(uname -m)" != "x86_64" ]; then
	echo "Not support host architecture (only for x86_64)"
	exit 1
fi

fn_usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-l locale] [-z timezone] [-s] [-i] [-p] [-q]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),armv7h(armhf),aarch64(arm64) (default : x64)"
	echo "          [-o output] : output dir (default : distro_archtecture)"
	echo "          [-l locale] : locale (default : ko_KR.UTF-8)"
	echo "          [-z timezone] : timezone (default : Asia/Seoul)"
	echo "          [-s] : skip image update"
	echo "          [-i] : import docker"
	echo "          [-p] : push image"
	echo "          [-q] : quiet"
	echo ""
	echo "          docker additional options:"
	echo "                [-n name:tag] : docker image name:tag"
	exit 1
}


DEBUG=Y

DOCKER_CMD="docker"
if [ -e /etc/synoinfo.conf ]; then
	DOCKER_CMD='sudo docker'
fi
TAR_CMD="sudo tar"


TARGET_DISTRO=
TARGET_ARCH=
TARGET_OUTPUT=
TARGET_LOCALE=
TARGET_NAME=
TARGET_UPDATE=
TARGET_IMPORT=
TARGET_PUSH=
TARGET_QEMU=

FORCE=

QUIET=

EXTRA_ARGS=

while [[ ${#} > 0 ]]
do
	case "${1}" in
		-d|--distro) TARGET_DISTRO="${2}" ; shift 1 ;;
		-a|--arch|--archtecture) TARGET_ARCH="${2}" ; shift 1 ;;
		-o|--out|--output) TAGET_OUTPUT="${2}" ; shift 1 ;;
		-l|--locale) TARGET_LOCALE="${2}" ; shift 1 ;;
		-n|--name) TARGET_NAME="${2}" ; shift 1 ;;
		-s|--skip) TARGET_UPDATE="N" ;;
		-i|--import) TARGET_IMPORT="Y" ;;
		-p|--push) TARGET_PUSH="Y" ;;
		-f|--force) FORCE="Y" ;;
		-q|--quiet) QUIET="Y" ;;
		-h|--help) fn_usage ;;
	   	*) EXTRA_ARGS+=(${1}) ;;
	esac
	shift
done

#set default
if [ -z "${TARGET_DISTRO}" ]; then
	TARGET_DISTRO=arch
fi
if [ "${TARGET_DISTRO}" != "alpine" -a "${TARGET_DISTRO}" != "arch" -a "${TARGET_DISTRO}" != "debian" -a "${TARGET_DISTRO}" != "ubuntu" ]; then
	fn_usage
fi
if [ -z "${TARGET_ARCH}" -o "${TARGET_ARCH}" = "x86_64" ]; then
	TARGET_ARCH=x64
fi
if [ "${TARGET_ARCH}" = "armv7h" ]; then
	TARGET_ARCH=armhf
fi
if [ "${TARGET_ARCH}" = "arm64" ]; then
	TARGET_ARCH=aarch64
fi
if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "armhf" -a "${TARGET_ARCH}" != "aarch64" ]; then
	fn_usage
fi
if [ -z "${TARGET_OUTPUT}" ]; then
	TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}
fi
if [ -z "${TARGET_LOCALE}" ]; then
	TARGET_LOCALE=ko_KR.UTF-8
fi
if [ -z "${TARGET_NAME}" ]; then
	TARGET_NAME=forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base
fi
if [ "${TARGET_UPDATE}" != "N" ]; then
	TARGET_UPDATE="Y"
fi
if [ "${TARGET_IMPORT}" != "Y" ]; then
	TARGET_IMPORT="N"
fi
if [ "${TARGET_PUSH}" != "Y" ]; then
	TARGET_PUSH="N"
fi
if [ "${TARGET_PUSH}" = "Y" ]; then
	TARGET_IMPORT="Y"
fi

#qemu check
if [ "${TARGET_ARCH}" = "armhf" ]; then
	if [ ! -e /proc/sys/fs/binfmt_misc/arm ]; then
		echo "Cross compile needs binfmt"
		#exit 1
	fi
	TARGET_QEMU=qemu-arm-static
elif [ "${TARGET_ARCH}" = "aarch64" ]; then
	if [ ! -e /proc/sys/fs/binfmt_misc/aarch64 ]; then
		echo "Cross compile needs binfmt"
		#exit 1
	fi
	TARGET_QEMU=qemu-aarch64-static
fi

#confirm
if [ "${QUIET}" != "Y" ]; then
	echo "TARGET_DISTRO=${TARGET_DISTRO}"
	echo "TARGET_ARCH=${TARGET_ARCH}"
	echo "TARGET_OUTPUT=${TARGET_OUTPUT}"
	echo "TARGET_LOCALE=${TARGET_LOCALE}"
	echo "TARGET_NAME=${TARGET_NAME}"
	echo "TARGET_UPDATE=${TARGET_UPDATE}"
	echo "TARGET_IMPORT=${TARGET_IMPORT}"
	echo "TARGET_PUSH=${TARGET_PUSH}"
	echo ""
	echo "FORCE=${FORCE}"
	echo ""
fi
if [ ! -e "${TARGET_OUTPUT}" ]; then
	echo "Cannot found output(${TARGET_OUTPUT})"
	exit 1
fi
if [ "${FORCE}" != "Y" ]; then
	echo "Do you want to do this now? [y|N]"
	read -r confirm
	if [[ ${confirm} =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
	else
		fn_usage
	fi
fi

if [ "${TARGET_UPDATE}" = "Y" ]; then
	rnd=${RANDOM}
	run_alt=/tmp/$(basename "${0}")-docker-run-alt-${rnd}
	rm -rf "${run_alt}"
	cat << EOF > ${run_alt}
#!/bin/sh

pushd /build &> /dev/null
./update-image.sh -d ${TARGET_DISTRO} -a ${TARGET_ARCH} -o ${TARGET_OUTPUT} -l ${TARGET_LOCALE} $([ ! -z "${TARGET_NAME}" ] && echo "-n ${TARGET_NAME}") $([ "${TARGET_UPDATE}" = "N" ] && echo "-s") -f -q
popd &> /dev/null
EOF
	chmod 755 ${run_alt}

	if [ ! -e ${run_alt} ]; then
		echo "${run_alt} error"
		rm -rf "${run_alt}"
		exit 1
	fi

	#dockercmd -q -z run -v `pwd`:/build -v ${run_alt}:/usr/local/bin/docker-run-alt $([ -e `pwd`/extra/qemu-arm-static ] && echo "-v `pwd`/extra/qemu-arm-static:/usr/bin/qemu-arm-static") $([ -e `pwd`/extra/qemu-aarch64-static ] && echo "-v `pwd`/extra/qemu-aarch64-static:/usr/bin/qemu-aarch64-static") arch-dev
	${DOCKER_CMD} run -i -t --rm --sig-proxy=false --privileged -e RUN_USER_NAME=forumi0721 -e RUN_USER_UID=1026 -e RUN_USER_GID=100 -e LANG=ko_KR.UTF-8 -e LC_ALL=ko_KR.UTF-8 -v `pwd`:/build -v ${run_alt}:/usr/local/bin/docker-run-alt $([ -e `pwd`/extra/qemu-arm-static ] && echo "-v `pwd`/extra/qemu-arm-static:/usr/bin/qemu-arm-static") $([ -e `pwd`/extra/qemu-aarch64-static ] && echo "-v `pwd`/extra/qemu-aarch64-static:/usr/bin/qemu-aarch64-static") -v /Workspace:/Workspace -v /Repository:/Repository -v /volume1/@docker_overlay/arch-dev/home_forumi0721:/home/forumi0721 -v /volume1/@docker_overlay/arch-dev/docker-run-pre:/usr/local/bin/docker-run-pre -h arch-x64-dev-${rnd} --name arch-x64-dev-${rnd}  forumi0721archx64/arch-x64-dev:latest
	rm -rf "${run_alt}"
fi

if [ "${TARGET_IMPORT}" = "Y" ]; then
	for id in $(${DOCKER_CMD} ps -a -q -f ancestor=${TARGET_NAME})
	do
		${DOCKER_CMD} rm -f ${id}
	done
	for id in $(${DOCKER_CMD} images -a -q ${TARGET_NAME})
	do
		${DOCKER_CMD} rmi -f ${id}
	done

	#import
	cmd=
	shell=
	if [ -e "${TARGET_OUTPUT}/bin/bash" ]; then
		shell=/bin/bash
	else
		shell=/bin/sh
	fi

	if [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			#cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"USER root\" --change \"CMD ${shell} --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
			cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"ENTRYPOINT ${shell}\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			#cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"USER root\" --change \"CMD ${shell} --login\" - ${TARGET_NAME}:latest"
			cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"ENTRYPOINT ${shell}\" - ${TARGET_NAME}:latest"
		fi
	else
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			#cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD ${shell} --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
			cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"ENTRYPOINT ${shell}\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			cmd="${TAR_CMD} --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | ${DOCKER_CMD} import --change \"ENTRYPOINT ${shell}\" - ${TARGET_NAME}:latest"
		fi
	fi
	echo
	echo "COMMAND : ${cmd}"
	eval ${cmd}
	echo Success.
	echo
fi

if [ "${TARGET_PUSH}" = "Y" ]; then
	${DOCKER_CMD} push ${TARGET_NAME}:latest
fi

