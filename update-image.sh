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
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-l locale] [-z timezone] [-s] [-i] [-p] [-q]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),armv7h,aarch64 (default : x64)"
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
if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "armv7h" -a "${TARGET_ARCH}" != "aach64" ]; then
	fn_usage
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
if [ "${TARGET_ARCH}" = "armv7h" ]; then
	if [ ! -e /proc/sys/fs/binfmt_misc/arm ]; then
			echo "Cross compile needs binfmt"
			exit 1
	fi
	TARGET_QEMU=qemu-arm-static
elif [ "${TARGET_ARCH}" = "aarch64" ]; then
	if [ ! -e /proc/sys/fs/binfmt_misc/aarch64 ]; then
		echo "Cross compile needs binfmt"
		exit 1
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

#resolve
cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

#clear
rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-*

#qemu
if [ ! -z "${TARGET_QEMU}" ]; then
	cp -f extra/${TARGET_QEMU} "${TARGET_OUTPUT}/usr/bin/"
fi

#docker-install
if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
	cp -f extra/docker-install.arch ${TARGET_OUTPUT}/usr/local/bin/docker-install
	cp extra/docker-sysusers ${TARGET_OUTPUT}/usr/local/bin/
	#cp extra/docker-tmpfiles ${TARGET_OUTPUT}/usr/local/bin/
elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=\(debian\|ubuntu\)" "${TARGET_OUTPUT}/etc/os-release")" ]; then
	cp -f extra/docker-install.deb ${TARGET_OUTPUT}/usr/local/bin/docker-install
elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
	cp -f extra/docker-install.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-install
fi
cp extra/docker-su ${TARGET_OUTPUT}/usr/local/bin/docker-su

#docker-build
if [ "${TARGET_ARCH}" = "armv7h" ]; then
	cp -f extra/docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/"
	ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
	if [ -e ${TARGET_OUTPUT}/lib/ld-musl-armhf.so.1 ]; then
		cp extra/docker-execve-check.armv7h.musl ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
	else
		cp extra/docker-execve-check.armv7h.glibc ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
	fi
	cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/
elif [ "${TARGET_ARCH}" = "aarch64" ]; then
	cp -f extra/docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/"
	ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
	if [ -e ${TARGET_OUTPUT}/lib/ld-musl-aarch64.so.1 ]; then
		cp extra/docker-execve-check.aarch64.musl ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
	else
		cp extra/docker-execve-check.aarch64.glibc ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
	fi
	cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
else
	cp -f extra/docker-build-x64 "${TARGET_OUTPUT}/usr/local/bin/docker-build"
	ln -sf docker-build "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
	ln -sf docker-build "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
	cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
fi


#update
prev_md5=
post_md5=
if [ "${TARGET_UPDATE}" = "Y" ]; then
	if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
		prev_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/pacman/local 2> /dev/null | md5sum | cut -f 1 -d ' ')
	elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=\(debian\|ubuntu\)" "${TARGET_OUTPUT}/etc/os-release")" ]; then
		prev_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/dpkg/info 2> /dev/null | md5sum | cut -f 1 -d ' ')
	elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
		prev_md5=$(md5sum ${TARGET_OUTPUT}/lib/apk/db/installed | cut -f 1 -d ' ')
	fi
	
	if [ ! -z "${TARGET_QEMU}" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve -0 /bin/sh /bin/sh -c "docker-install -r -u -c"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "docker-install -r -u -c"
	fi

	if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
		post_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/pacman/local 2> /dev/null | md5sum | cut -f 1 -d ' ')
	elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=debian" "${TARGET_OUTPUT}/etc/os-release")" ]; then
		post_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/dpkg/info 2> /dev/null | md5sum | cut -f 1 -d ' ')
	elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=ubuntu" "${TARGET_OUTPUT}/etc/os-release")" ]; then
		post_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/dpkg/info 2> /dev/null | md5sum | cut -f 1 -d ' ')
	elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
		post_md5=$(md5sum ${TARGET_OUTPUT}/lib/apk/db/installed | cut -f 1 -d ' ')
	fi
	echo

	if [ ! -z "${prev_md5}" -a ! -z "${post_md5}" ]; then
		echo "PREV_MD5 : ${prev_md5}"
		echo "POST_MD5 : ${post_md5}"
		if [ "${prev_md5}" = "${post_md5}" ]; then
			echo "Already up-to-date"
		else
			echo "Distro update"
		fi
		echo
	fi
fi


if [ -e "${TARGET_OUTPUT}/etc/os-release"  ]; then
	if [ ! -z "$(grep 'ID=\(debian\|ubuntu\)' "${TARGET_OUTPUT}/etc/os-release")" ]; then
		find ${TARGET_OUTPUT}/var -name \*.log -o -name \*-old -exec rm -rf "{}" \;
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
	shell=
	if [ -e "${TARGET_OUTPUT}/bin/bash" ]; then
		shell=/bin/bash
	else
		shell=/bin/sh
	fi

	if [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			#cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"USER root\" --change \"CMD ${shell} --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT ${shell}\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			#cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"USER root\" --change \"CMD ${shell} --login\" - ${TARGET_NAME}:latest"
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT ${shell}\" - ${TARGET_NAME}:latest"
		fi
	else
		if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
			#cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD ${shell} --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT ${shell}\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		else
			cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT ${shell}\" - ${TARGET_NAME}:latest"
		fi
	fi
	echo
	echo "COMMAND : ${cmd}"
	eval ${cmd}
	echo Success.
	echo
fi

if [ "${TARGET_PUSH}" = "Y" ]; then
	if [ ! -z "${SUDO_USER}" ]; then
		su -s /bin/sh -c "docker push ${TARGET_NAME}:latest" - ${SUDO_USER}
	else
		docker push ${TARGET_NAME}:latest
	fi
fi

