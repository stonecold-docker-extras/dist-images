#!/usr/bin/env bash

LANG="C"
LC_ALL="C"

echo_red() {
	echo -e "\e[0;31m${1}\e[0m"
}

echo_green() {
	echo -e "\e[0;32m${1}\e[0m"
}

echo_blue() {
	echo -e "\e[0;34m${1}\e[0m"
}

fn_usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-t type] [-l locale] [-z timezone] [-c] [-r] [-i include packages] [-e exclude pacakges]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),armv7h(armhf),aarch64(arm64) (default : x64)"
	echo "          [-o output] : output dir (default : distro_archtecture)"
	echo "          [-t type] : docker,native (default : docker)"
	echo "          [-l locale] : locale (default : ko_KR.UTF-8)"
	echo "          [-z timezone] : timezone (default : Asia/Seoul)"
	echo "          [-c] : compress image (default : false)"
	echo "          [-r] : remove rootdir (default : false)"
	echo "          [-k] : import docker (default : false)"
	echo "          [-p] : push docker (default : false)"
	echo "          [-i include pacakges] : include pacakges (default : null)"
	echo "          [-e exclude pacakges] : exclude pacakges (default : null)"
	exit 1
}

DEBUG=Y

TARGET_DISTRO=
TARGET_ARCH=
TARGET_OUTPUT=
TARGET_TYPE=
TARGET_LOCALE=
TARGET_TIMEZONE=
TARGET_IMPORT=
TARGET_PUSH=
TARGET_NAME=
TARGET_QEMU=

TARGET_COMPRESS=
TARGET_REMOVE=

INCLUDE_PACKAGES=
EXCLUDE_PACKAGES=

FORCE=

EXTRA_ARGS=

while [[ ${#} > 0 ]]
do
	case "${1}" in
		-d|--distro) TARGET_DISTRO="${2}" ; shift 1 ;;
		-a|--arch|--archtecture) TARGET_ARCH="${2}" ; shift 1 ;;
		-o|--out|--output) TAGET_OUTPUT="${2}" ; shift 1 ;;
		-t|--type) TARGET_TYPE="${2}" ; shift 1 ;;
		-l|--locale) TARGET_LOCALE="${2}" ; shift 1 ;;
		-z|--timezone) TARGET_TIMEZONE="${2}" ; shift 1 ;;
		-k|--docker) TARGET_IMPORT="Y" ;;
		-p|--push) TARGET_PUSH="Y" ;;
		-c|--compress) TARGET_COMPRESS="Y" ;;
		-r|--rm) TARGET_REMOVE="Y" ;;
		-i|--include) INCLUDE_PACKAGES="${2}" ; shift 1 ;;
		-e|--exclude) EXCLUDE_PACKAGES="${2}" ; shift 1 ;;
		-n|--name) TARGET_NAME="${2}" ; shift 1 ;;
		-f|--force) FORCE="Y" ; shift 1 ;;
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
if [ -z "${TARGET_TYPE}" ]; then
	TARGET_TYPE=docker
fi
if [ "${TARGET_TYPE}" != "docker" -a "${TARGET_TYPE}" != "native" ]; then
	fn_usage
fi
if [ -z "${TARGET_LOCALE}" ]; then
	TARGET_LOCALE=ko_KR.UTF-8
fi
if [ -z "${TARGET_TIMEZONE}" ]; then
	TARGET_TIMEZONE=Asia/Seoul
fi
if [ -z "${TARGET_IMPORT}" ]; then
	TARGET_IMPORT="N"
fi
if [ -z "${TARGET_PUSH}" ]; then
	TARGET_PUSH="N"
fi
if [ "${TARGET_COMPRESS}" != "Y" ]; then
	TARGET_COMPRESS="N"
fi
if [ "${TARGET_REMOVE}" != "Y" ]; then
	TARGET_REMOVE="N"
fi
if [ "${TARGET_TYPE}" = "docker" ]; then
	if [ -z "${TARGET_NAME}" ]; then
		TARGET_NAME=forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base
	fi
else
	TARGET_NAME=
fi

#qemu check
if [ "${TARGET_ARCH}" = "armhf" -o "${TARGET_ARCH}" = "armel" ]; then
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
echo "TARGET_DISTRO=${TARGET_DISTRO}"
echo "TARGET_ARCH=${TARGET_ARCH}"
echo "TARGET_OUTPUT=${TARGET_OUTPUT}"
echo "TARGET_TYPE=${TARGET_TYPE}"
echo "TARGET_LOCALE=${TARGET_LOCALE}"
echo "TARGET_TIMEZONE=${TARGET_TIMEZONE}"
echo "TARGET_COMPRESS=${TARGET_COMPRESS}"
echo "TARGET_REMOVE=${TARGET_REMOVE}"
echo "TARGET_NAME=${TARGET_NAME}"
echo "TARGET_QEMU=${TARGET_QEMU}"
echo ""
echo "INCLUDE_PACKAGES=${INCLUDE_PACKAGES}"
echo "EXCLUDE_PACKAGES=${EXCLUDE_PACKAGES}"
echo ""
echo "EXTRA_ARGS=${EXTRA_ARGS}"
echo ""
echo "FORCE=${FORCE}"
echo ""
if [ "${FORCE}" != "Y" ]; then
	echo "Do you want to do this now? [y|N]"
	read -r confirm
	if [[ ${confirm} =~ ^([yY][eE][sS]|[yY])$ ]]; then
		echo ""
	else
		fn_usage
	fi
fi

if [ -e "${TARGET_OUTPUT}" ]; then
	R_PATH="$(realpath "${TARGET_OUTPUT}")"
	if [ ! -z "$(mount | grep "on ${R_PATH}.* type")" ]; then
		sudo umount -R "${R_PATH}"
		for a in $(mount | grep "on ${R_PATH}.* type" | sed 's/^.*on \(.*\) type.*$/\1/g')
		do
			sudo umount ${a}
		done
		if [ ! -z "$(mount | grep "on ${R_PATH}.* type")" ]; then
			echo "Cannot remove ${R_PATH}"
			exit 1
		fi
	fi
	if [ ! -z "$(mount | grep "on ${R_PATH}.* type")" ]; then
		echo "Cannot remove ${R_PATH}"
		exit 1
	fi
	sudo rm -rf "${R_PATH}" || (echo "Cannot remove ${R_PATH}" ; exit 1)
fi
if [ -e "${TARGET_OUTPUT}" ]; then
	echo "Cannot remove ${R_PATH}"
	exit 1
fi

run_alt=/tmp/$(basename "${0}")-docker-run-alt
rm -rf "${run_alt}"
cat << EOF > ${run_alt}
#!/bin/sh

pushd /build &> /dev/null
./make-image.sh -d ${TARGET_DISTRO} -a ${TARGET_ARCH} -o ${TARGET_OUTPUT} -t ${TARGET_TYPE} -l ${TARGET_LOCALE} -z "${TARGET_TIMEZONE}" $([ "${TARGET_COMPRESS}" = "Y" ] && echo "-c"]) $([ "${TARGET_REMOVE}" = "Y" ] && echo "-r") $([ ! -z "${INCLUDE_PACKAGES}" ] && echo "-i ${INCLUDE_PACKAGES}") $([ ! -z "${EXCLUDE_PACKAGES}" ] && echo "-e ${EXCLUDE_PACKAGES}") -f
popd &> /dev/null
EOF
chmod 755 ${run_alt}

if [ ! -e ${run_alt} ]; then
	echo "${run_alt} error"
	rm -rf "${run_alt}"
	exit 1
fi

dockercmd -z run -v `pwd`:/build -v ${run_alt}:/usr/local/bin/docker-run-alt $([ -e `pwd`/extra/qemu-arm-static ] && echo "-v `pwd`/extra/qemu-arm-static:/usr/bin/qemu-arm-static") $([ -e `pwd`/extra/qemu-aarch64-static ] && echo "-v `pwd`/extra/qemu-aarch64-static:/usr/bin/qemu-aarch64-static") arch-dev
rm -rf "${run_alt}"

DOCKER_CMD="sudo docker"
TAR_CMD="sudo tar"

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

