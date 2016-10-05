#!/usr/bin/env bash

if [ "${UID}" -ne 0 ]; then
	sudo "${0}" $*
	exit $?
fi

LANG="C"
LC_ALL="C"

if [ "$(uname -m)" != "x86_64" ]; then
	echo "Not support host architecture (only for x86_64)"
	exit 1
fi

fn_usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-l locale] [-z timezone] [-u] [-i]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),x86(i686),armv5(arm),armv6h,armv7h,aarch64 (default : x64)"
	echo "          [-o output] : output dir (default : distro_archtecture)"
	echo "          [-l locale] : locale (default : ko_KR.UTF-8)"
	echo "          [-z timezone] : timezone (default : Asia/Seoul)"
	echo "          [-u] : image update"
	echo "          [-i] : import docker"
	echo ""
	echo "          docker additional options:"
	echo "                [-n name:tag] : docker image name:tag"
	exit 1
}


DEBUG=Y

TARGET_DISTRO=
TARGET_ARCH=
TARGET_OUTPUT=
TARGET_LOCALE=
TARGET_NAME=
TARGET_UPDATE=
TARGET_IMPORT=

FORCE=

EXTRA_ARGS=

while [[ ${#} > 0 ]]
do
	case "${1}" in
		-d|--distro) TARGET_DISTRO="${2}" ; shift 1 ;;
		-a|--arch|--archtecture) TARGET_ARCH="${2}" ; shift 1 ;;
		-o|--out|--output) TAGET_OUTPUT="${2}" ; shift 1 ;;
		-l|--locale) TARGET_LOCALE="${2}" ; shift 1 ;;
		-n|--name) TARGET_NAME="${2}" ; shift 1 ;;
		-u|--update) TARGET_UPDATE="Y" ;;
		-i|--import) TARGET_IMPORT="Y" ;;
		-f|--force) FORCE="Y" ;;
		-h|--help) fn_usage ;;
	   	*) EXTRA_ARGS+=(${1}) ;;
	esac
	shift
done

#set default
if [ "${TARGET_DISTRO}" != "debian" -a "${TARGET_DISTRO}" != "ubuntu" -a "${TARGET_DISTRO}" != "alpine" ]; then
	TARGET_DISTRO=arch
fi
if [ "${TARGET_ARCH}" = "x86_64" ]; then
	TARGET_ARCH=x64
fi
if [ "${TARGET_ARCH}" = "i686" ]; then
	TARGET_ARCH=x86
fi
if [ "${TARGET_ARCH}" = "arm" ]; then
	TARGET_ARCH=armv5
fi
if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" -a "${TARGET_ARCH}" != "armv5" -a "${TARGET_ARCH}" != "armv6h" -a "${TARGET_ARCH}" != "armv7h" -a "${TARGET_ARCH}" != "aarch64" ]; then
	TARGET_ARCH=x64
fi
if [ -z "${TARGET_OUTPUT}" ]; then
	TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}
	TARGET_OUTPUT=$(realpath ${TARGET_OUTPUT})
fi
if [ -z "${TARGET_LOCALE}" ]; then
	TARGET_LOCALE=ko_KR.UTF-8
fi
if [ -z "${TARGET_NAME}" ]; then
	TARGET_NAME=forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base
fi
if [ "${TARGET_UPDATE}" != "Y" ]; then
	TARGET_UPDATE="N"
fi
if [ "${TARGET_IMPORT}" != "Y" ]; then
	TARGET_IMPORT="N"
fi

#confirm
echo "TARGET_DISTRO=${TARGET_DISTRO}"
echo "TARGET_ARCH=${TARGET_ARCH}"
echo "TARGET_OUTPUT=${TARGET_OUTPUT}"
echo "TARGET_LOCALE=${TARGET_LOCALE}"
echo "TARGET_NAME=${TARGET_NAME}"
echo "TARGET_UPDATE=${TARGET_UPDATE}"
echo "TARGET_IMPORT=${TARGET_IMPORT}"
echo ""
echo "FORCE=${FORCE}"
echo ""
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

#resolve
cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

#qemu
if [ -e "${TARGET_OUTPUT}/usr/bin/qemu-arm-static" ]; then
	cp -f extra/qemu-arm-static "${TARGET_OUTPUT}/usr/bin/qemu-arm-static"
elif [ -e "${TARGET_OUTPUT}/usr/bin/qemu-aarch64-static" ]; then
	cp -f extra/qemu-aarch64-static "${TARGET_OUTPUT}/usr/bin/qemu-aarch64-static"
fi
if [ -e "${TARGET_OUTPUT}/usr/local/bin/docker-build-arm" ]; then
	cp -f extra/docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-arm"
	ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
elif [ -e "${TARGET_OUTPUT}/usr/local/bin/docker-build-aarch64" ]; then
	cp -f extra/docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-aarch64"
	ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
else
	cp -f extra/docker-build-start "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	cp -f extra/docker-build-end "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
fi

#docker-install
if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
	cp -f extra/docker-install.arch ${TARGET_OUTPUT}/usr/local/bin/docker-install
elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=debian" "${TARGET_OUTPUT}/etc/os-release")" ]; then
	cp -f extra/docker-install.deb ${TARGET_OUTPUT}/usr/local/bin/docker-install
elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=ubuntu" "${TARGET_OUTPUT}/etc/os-release")" ]; then
	cp -f extra/docker-install.deb ${TARGET_OUTPUT}/usr/local/bin/docker-install
elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
	cp -f extra/docker-install.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-install
fi

#update
if [ "${TARGET_UPDATE}" = "Y" ]; then
	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C arch-chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "docker-install -r -u -c"
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C arch-chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "docker-install -r -u -c"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "docker-install -r -u -c"
	fi
fi

if [ "${TARGET_IMPORT}" = "Y" ]; then
	for id in $(docker ps -a -q -f ancestor=${TARGET_NAME})
	do
		docker rm -f ${id}
	done
	for id in $(docker images -a -q ${TARGET_NAME})
	do
		docker rmi -f ${id}
	done

	#import
	cmd=
	if [ ! -e "${TARGET_OUTPUT}/bin/bash" ]; then
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/sh --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/sh --login\" - ${TARGET_NAME}:latest"
		fi
	else
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/bash --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/bash --login\" - ${TARGET_NAME}:latest"
		fi
	fi
	echo
	echo "COMMAND : ${cmd}"
	eval ${cmd}
	echo Success.
	echo
fi
