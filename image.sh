#!/usr/bin/env bash

if [ "${EUID}" != "0" ]; then
	sudo "${0}" "${@}"
	exit $?
fi

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

fn_run_docker() {
	if ! docker info &> /dev/null ; then
		echo "Cannot execute docker (1)"
		exit 1
	fi

	local dockername=alpine-x64-dev-docker-dist-${RANDOM}
	local dockerdir=/build
	local workdir="$(pwd)"
	local workscript="${workdir}/$(basename "${0}")"
	local user=$(id -n -u)
	local uid=$(id -u)
	local gid=$(id -g)
	local lang=${LANG:-ko_KR.UTF-8}
	local lc_all=${LC_ALL:-ko_KR.UTF-8}


	echo "Execute in docker"
	if [ "${DEBUG}" = "Y" ]; then
		echo "Arguments : $@"
	fi

	[ "${DEBUG}" = "Y" ] && set -x
	docker run  --rm --sig-proxy=false --privileged -e RUN_USER_NAME=${user} -e RUN_USER_UID=${uid} -e RUN_USER_GID=${gid} -e LANG=${lang} -e LC_ALL=${lc_all} -v ${workdir}:${dockerdir} -v ${workscript}:/usr/local/bin/docker-run-alt -v ${workdir}/extra/qemu-arm-static:/usr/bin/qemu-arm-static -v ${workdir}/extra/qemu-aarch64-static:/usr/bin/qemu-aarch64-static -h ${dockername} --name ${dockername} -e DOCKER_WORKDIR=${dockerdir} forumi0721alpinex64/alpine-x64-dev:latest - "${@}"
	[ "${DEBUG}" = "Y" ] && set +x
}

fn_usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-l locale] [-z timezone] [--include include packages] [--exclud exclude pacakges] [-m] [-s] [-i] [-p] [-q]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),armv7h(armhf),aarch64(arm64) (default : x64)"
	echo "          [-e edition] : debian, ubuntu option"
	echo "          [-o output] : output dir (default : distro_archtecture)"
	echo "          [-l locale] : locale (default : ko_KR.UTF-8)"
	echo "          [-z timezone] : timezone (default : Asia/Seoul)"
	echo "          [--include include pacakges] : include pacakges (default : null)"
	echo "          [--exclude exclude pacakges] : exclude pacakges (default : null)"
	echo "          [-m] : make image"
	echo "          [-u] : update umage"
	echo "          [-i] : import docker"
	echo "          [-p] : push image"
	echo "          [-q] : quiet"
	echo ""
	echo "          docker additional options:"
	echo "                [-n name:tag] : docker image name:tag"
	exit 1
}

fn_target_unmount() {
if [ -e "${TARGET_OUTPUT}" ]; then
	if [ ! -z "$(mount | grep "on ${TARGET_OUTPUT}.* type")" ]; then
		umount -R "${TARGET_OUTPUT}"
		for a in $(mount | grep "on ${TARGET_OUTPUT}.* type" | sed 's/^.*on \(.*\) type.*$/\1/g')
		do
			umount ${a}
		done
		if [ ! -z "$(mount | grep "on ${TARGET_OUTPUT}.* type")" ]; then
			echo "Cannot remove ${TARGET_OUTPUT}"
			exit 1
		fi
	fi
fi
}

fn_make_alpine() {
	echo "Bootstrap"

	#local ALPINE_DIST=edge
	#local ALPINE_DIST=v3.8
	#ALPINE_DIST="$(curl -sSL http://dl-cdn.alpinelinux.org/alpine | grep '<a href="v' | tail -1 | sed -e 's/^<a href="\(.*\)\/">.*$/\1/g')"
	local ALPINE_DIST=latest-stable
	ALPINE_DIST="${ALPINE_DIST:-latest-stable}"
	echo "Current version : ${ALPINE_DIST}"
	#local ALPINE_MIRROR=http://dl-cdn.alpinelinux.org/alpine
	local ALPINE_MIRROR=http://mirror.xtom.com.hk/alpine
	#local ALPINE_MIRROR=http://dl-2.alpinelinux.org/alpine

	local ALPINE_ARCH=${TARGET_ARCH}
	ALPINE_ARCH=${ALPINE_ARCH/x64/x86_64}
	ALPINE_ARCH=${ALPINE_ARCH/armv7h/armhf}
	ALPINE_ARCH=${ALPINE_ARCH/aarch64/aarch64}

	#qemu
	if [ ! -z "${TARGET_QEMU}" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		cp extra/${TARGET_QEMU} ${TARGET_OUTPUT}/usr/bin/
	fi
	local APK_VERSION="$(wget -q -O - ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/APKINDEX.tar.gz | tar -Oxz | grep --text '^P:apk-tools-static$' -A1 | tail -n1 | cut -d: -f2)"
	wget -q -O - ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/apk-tools-static-${APK_VERSION}.apk | tar -xz -C "${TARGET_OUTPUT}" sbin/apk.static  2>/dev/null

	if [ ! -z "${TARGET_QEMU}" ]; then
		QEMU_EXECVE=1 /usr/bin/${TARGET_QEMU} -execve ${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --no-script --allow-untrusted --root "${TARGET_OUTPUT}" --initdb add busybox alpine-baselayout alpine-keys apk-tools libc-utils
		for link in $(QEMU_EXECVE=1 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/bin/busybox --list-full"); do
			[ -e "${TARGET_OUTPUT}"/$link ] || ln -s /bin/busybox "${TARGET_OUTPUT}"/$link
		done
		QEMU_EXECVE=1 /usr/bin/${TARGET_QEMU} -execve ${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --allow-untrusted --root "${TARGET_OUTPUT}" --stdout --quiet fetch alpine-base | tar -zx -C "${TARGET_OUTPUT}" etc/
	else
		${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --no-script --allow-untrusted --root "${TARGET_OUTPUT}" --initdb add busybox alpine-baselayout alpine-keys apk-tools libc-utils
		for link in $("${TARGET_OUTPUT}"/bin/busybox --list-full); do
			[ -e "${TARGET_OUTPUT}"/$link ] || ln -s /bin/busybox "${TARGET_OUTPUT}"/$link
		done
		${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --allow-untrusted --root "${TARGET_OUTPUT}" --stdout --quiet fetch alpine-base | tar -zx -C "${TARGET_OUTPUT}" etc/
	fi

	echo

	echo "Configuration"

	#mirror
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/main" > ${TARGET_OUTPUT}/etc/apk/repositories
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/community" >> ${TARGET_OUTPUT}/etc/apk/repositories
	if [ "${ALPINE_DIST}" != "edge" ]; then
		#echo "Disable edge"
		echo "${ALPINE_MIRROR}/edge/main" >> ${TARGET_OUTPUT}/etc/apk/repositories
		echo "${ALPINE_MIRROR}/edge/community" >> ${TARGET_OUTPUT}/etc/apk/repositories
		echo "${ALPINE_MIRROR}/edge/testing" >> ${TARGET_OUTPUT}/etc/apk/repositories
	else
		echo "${ALPINE_MIRROR}/edge/testing" >> ${TARGET_OUTPUT}/etc/apk/repositories
	fi

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

	#timezone
	echo "${TARGET_TIMEZONE}" > ${TARGET_OUTPUT}/etc/TZ
	#if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
	#	ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime
	#fi
	local tz1=$(echo "${TARGET_TIMEZONE}" | cut -d '/' -f 1)
	local tz2=$(echo "${TARGET_TIMEZONE}" | cut -d '/' -f 2)
	mkdir -p ${TARGET_OUTPUT}/tmp/tzdata
	if [ ! -z "${TARGET_QEMU}" ]; then
		QEMU_EXECVE=1 /usr/bin/${TARGET_QEMU} -execve ${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --allow-untrusted --root "${TARGET_OUTPUT}" --stdout --quiet fetch tzdata | tar -zx -C "${TARGET_OUTPUT}/tmp/tzdata" usr/share/zoneinfo
	else
		${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --no-cache --allow-untrusted --root "${TARGET_OUTPUT}" --stdout --quiet fetch tzdata | tar -zx -C "${TARGET_OUTPUT}/tmp/tzdata" usr/share/zoneinfo
	fi
	if [ -e ${TARGET_OUTPUT}/tmp/tzdata/usr/share/zoneinfo/${tz1}/${tz2} ]; then
		mkdir -p ${TARGET_OUTPUT}/etc/zoneinfo/${tz1}
		cp ${TARGET_OUTPUT}/tmp/tzdata/usr/share/zoneinfo/${tz1}/${tz2} ${TARGET_OUTPUT}/etc/zoneinfo/${tz1}/${tz2}
		ln -sf /etc/zoneinfo/${tz1}/${tz2} ${TARGET_OUTPUT}/etc/localtime
	fi
	rm -rf ${TARGET_OUTPUT}/tmp/tzdata

	echo


	echo "Clearing"

	rm -rf ${TARGET_OUTPUT}/sbin/apk.static
	rm -rf ${TARGET_OUTPUT}/var/cache/apk/*
	rm -rf ${TARGET_OUTPUT}/tmp/*

	echo

	fn_make_common
}

fn_make_arch() {
	if ! pacstrap -h &>/dev/null ; then
		echo "Could not find pacstrap. Run pacman -S arch-install-scripts"
		exit 1
	fi

	if ! arch-chroot -h &>/dev/null ; then
		echo "Could not find arch-chroot. Run pacman -S arch-install-scripts"
		exit 1
	fi

	echo "Bootstrap"

	local PACMAN_MIRRORLIST=
	#local PACMAN_BASE_PKGS=(bash bzip2 coreutils diffutils filesystem findutils gettext glibc grep gzip less pacman perl procps-ng sed shadow systemd)
	local PACMAN_BASE_PKGS="bash coreutils diffutils filesystem findutils gettext glibc grep gzip less pacman procps-ng sed systemd haveged"
	#local PACMAN_REMOVE_PKGS="diffutils gettext gzip less procps-ng haveged"
	local PACMAN_REMOVE_PKGS="gzip less procps-ng haveged"
	local PACMAN_EXTRA_PKGS=""
	local ARCH_KEYRING=

	local ARCH_ARCH=${TARGET_ARCH}
	ARCH_ARCH=${ARCH_ARCH/x64/x86_64}
	ARCH_ARCH=${ARCH_ARCH/armhf/armv7h}
	ARCH_ARCH=${ARCH_ARCH/aarch64/aarch64}

	if [ -z "$(ls /var/cache/pacman/pkg | grep "${ARCH_ARCH}.pkg.tar.xz")" ]; then
		rm -rf /var/cache/pacman/pkg/*
	fi

	if [ "${ARCH_ARCH}" = "armv7h" -o "${ARCH_ARCH}" = "aarch64" ]; then
		PACMAN_MIRRORLIST='Server = http://mirror.archlinuxarm.org/$arch/$repo'
		#PACMAN_MIRRORLIST='Server = http://tw.mirror.archlinuxarm.org/$arch/$repo'
		PACMAN_EXTRA_PKGS="archlinuxarm-keyring"
		ARCH_KEYRING="archlinuxarm"
	else
		PACMAN_MIRRORLIST='Server = http://mirror.premi.st/archlinux/$repo/os/$arch'
		PACMAN_EXTRA_PKGS=""
		ARCH_KEYRING="archlinux"
	fi

	PACMAN_CONF="${TARGET_OUTPUT}/pacman.conf"

	cat << EOF > "${PACMAN_CONF}"
[options]
HoldPkg = pacman glibc
Architecture = ${ARCH_ARCH}
SigLevel = Never
LocalFileSigLevel = Never
[core]
${PACMAN_MIRRORLIST}
[extra]
${PACMAN_MIRRORLIST}
[community]
${PACMAN_MIRRORLIST}
EOF
	if [ "${ARCH_ARCH}" = "x86_64" ]; then
	cat << EOF >> "${PACMAN_CONF}"
[multilib]
${PACMAN_MIRRORLIST}
EOF
	fi
	if [ "${ARCH_ARCH}" = "armv7h" -o "${ARCH_ARCH}" = "aarch64" ]; then
		cat << EOF >> "${PACMAN_CONF}"
[alarm]
${PACMAN_MIRRORLIST}
[aur]
${PACMAN_MIRRORLIST}
EOF
	fi

	#qemu
	if [ ! -z "${TARGET_QEMU}" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		cp extra/${TARGET_QEMU} ${TARGET_OUTPUT}/usr/bin/
	fi

	if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
		pacstrap -C ${PACMAN_CONF} -c -d -G -M "${TARGET_OUTPUT}" filesystem pacman shadow grep haveged

		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/haveged ; /usr/bin/rm -fr /etc/pacman.d/gnupg ; /usr/bin/pacman-key --init ; /usr/bin/pacman-key --populate ${ARCH_KEYRING} ; /usr/bin/pkill haveged ; /usr/bin/pkill gpg-agent"

		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/pacman -Suy --noconfirm ${PACMAN_BASE_PKGS} ${PACMAN_EXTRA_PKGS}"
	else
		pacstrap -C ${PACMAN_CONF} -c -d -G -M "${TARGET_OUTPUT}" filesystem pacman shadow grep

		pacstrap -C ${PACMAN_CONF} -c -d -G -M "${TARGET_OUTPUT}" ${PACMAN_BASE_PKGS} ${PACMAN_EXTRA_PKGS}
	fi

	echo

	echo "Configuration"

	#users gid
	sed -i "s/^users:x:.*$/users:x:100:/g" ${TARGET_OUTPUT}/etc/group


	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

	#systemd-sysusers
	if [ -e "${TARGET_OUTPUT}/usr/bin/systemd-sysusers" ]; then
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/systemd-sysusers"
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/bin/systemd-sysusers"
		fi
	fi

	#update-ca-trust
	if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "update-ca-trust"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "update-ca-trust"
	fi

	#keyring
	if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/haveged ; /usr/bin/rm -fr /etc/pacman.d/gnupg ; /usr/bin/pacman-key --init ; /usr/bin/pacman-key --populate ${ARCH_KEYRING} ; /usr/bin/pkill haveged ; /usr/bin/pkill gpg-agent"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/bin/haveged ; /usr/bin/rm -fr /etc/pacman.d/gnupg ; /usr/bin/pacman-key --init ; /usr/bin/pacman-key --populate ${ARCH_KEYRING} ; /usr/bin/pkill haveged ; /usr/bin/pkill gpg-agent"
	fi

	#basic config
	echo "${PACMAN_MIRRORLIST}" > ${TARGET_OUTPUT}/etc/pacman.d/mirrorlist
	sed -i "s/\(Architecture =\) auto/\1 ${ARCH_ARCH}/g" ${TARGET_OUTPUT}/etc/pacman.conf
	sed -i "s/#\(NoUpgrade   =\)/\1 \/etc\/pacman.d\/mirrorlist/g" ${TARGET_OUTPUT}/etc/pacman.conf

	#locale
	sed -i "s/#en_US.UTF-8/en_US.UTF-8/g" ${TARGET_OUTPUT}/etc/locale.gen
	sed -i "s/#${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8 ]; then
		rm -rf ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8
	fi
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz ]; then
		gzip -dk ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz
	fi
	if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "locale-gen"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/bin/locale-gen"
	fi
	echo "LANG=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/locale.conf
	echo "LC_ALL=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/locale.conf

	#timezone
	if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
		ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime
	fi

	#skel
	cp -ar ${TARGET_OUTPUT}/etc/skel/. ${TARGET_OUTPUT}/root/

	#yaourt
	if [ -e extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz -a -e extra/yaourt-*-any.pkg.tar.xz ]; then
		cp extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz ${TARGET_OUTPUT}/
		cp extra/yaourt-*-any.pkg.tar.xz ${TARGET_OUTPUT}/
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/pacman -Sy --noconfirm ; /usr/bin/pacman -U --noconfirm --asdeps /package-query-*; /usr/bin/pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz"
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/bin/pacman -Sy --noconfirm ; /usr/bin/pacman -U --noconfirm --asdeps /package-query-*; /usr/bin/pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz"
		fi
		rm -rf ${TARGET_OUTPUT}/*.pkg.tar.xz
	fi

	echo

	echo "Clearing"

	if [ ! -z "${PACMAN_REMOVE_PKGS}" ]; then
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/pacman -Rsn --noconfirm ${PACMAN_REMOVE_PKGS}"
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" arch-chroot "${TARGET_OUTPUT}" /bin/sh -c /usr/bin/"pacman -Rsn --noconfirm ${PACMAN_REMOVE_PKGS}"
		fi
	fi

	rm -rf "${PACMAN_CONF}"

	rm -rf ${TARGET_OUTPUT}/var/cache/pacman/pkg/*
	rm -rf ${TARGET_OUTPUT}/var/lib/pacman/sync/*
	rm -rf ${TARGET_OUTPUT}/tmp/yaourt*

	echo

	fn_make_common
}

fn_make_debian() {
	local DEBIAN_DIST=${TARGET_EDITION}
	if [ -z "${DEBIAN_DIST}" ]; then
		#DEBIAN_DIST="$(curl -sSL http://ftp.kaist.ac.kr/debian/dists/README | grep '^stable,' | sed -e 's/^stable, or \([^ ]\+\)\s\+.*$/\1/g')"
		#DEBIAN_DIST="${DEBIAN_DIST:-stretch}"
		DEBIAN_DIST="${DEBIAN_DIST:-stable}"
	fi
	echo "Current version : ${DEBIAN_DIST}"
	#local DEBIAN_MIRROR=http://ftp.kr.debian.org/debian
	#local DEBIAN_MIRROR=http://ftp.daumkakao.com/debian
	local DEBIAN_MIRROR=http://ftp.lanet.kr/debian
	local DEBIAN_EXTRA=locales

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	fn_make_debian_common "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

fn_make_ubuntu() {
	local DEBIAN_DIST=${TARGET_EDITION}
	if [ -z "${DEBIAN_DIST}" ]; then
		#DEBIAN_DIST="$(curl -sSL http://ftp.kaist.ac.kr/ubuntu/dists/ | grep -v 'backports' | grep -v 'proposed' | grep -v 'security' | grep -v 'updates' | grep '<tr><td class="n">' | tail -1  | sed -e 's/^<tr><td class="n"><a href="\(.*\)\/">.*$/\1/g')"
		DEBIAN_DIST="${DEBIAN_DIST:-bionic}"
	fi
	echo "Current version : ${DEBIAN_DIST}"
	local DEBIAN_MIRROR=
	#local DEBIAN_EXTRA="language-pack-ko"
	local DEBIAN_EXTRA="locales,tzdata"

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	if [ "${DEBIAN_ARCH}" = "armhf" -o "${DEBIAN_ARCH}" = "arm64" ]; then
		DEBIAN_MIRROR=http://ports.ubuntu.com/ubuntu-ports
	else
		#DEBIAN_MIRROR=http://kr.archive.ubuntu.com/ubuntu
		#DEBIAN_MIRROR=http://ftp.daumkakao.com/ubuntu
		DEBIAN_MIRROR=http://ftp.lanet.kr/ubuntu
	fi

	fn_make_debian_common "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

fn_make_debian_common() {
	if ! debootstrap --help &>/dev/null ; then
		#echo "Could not find debootstrap. Run pacman -S debootstrap"
		#exit 1
		pacman -Suy --noconfirm debootstrap
	fi

	alias apt-get="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true /usr/bin/apt-get -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=false -o APT::Install-Suggests=false" 
	alias debootstrap="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true /usr/bin/debootstrap -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=false -o APT::Install-Suggests=false"

	local DEBIAN_DIST="${1}"
	local DEBIAN_MIRROR="${2}"
	local DEBIAN_EXTRA=("${3}")
	local DEBIAN_ARCH=("${4}")
	local DEBIAN_OPTION=("--variant=minbase")
	if [ ! -z "${DEBIAN_EXTRA}" ]; then
		DEBIAN_OPTION=("${DEBIAN_OPTION[@]}" "--include=${DEBIAN_EXTRA}")
	fi
	DEBIAN_OPTION=("--arch=${DEBIAN_ARCH}" "${DEBIAN_OPTION[@]}")

	if [ ! -z "${TARGET_QEMU}" ]; then
		mkdir -p "${TARGET_OUTPUT}/usr/bin"
		cp extra/${TARGET_QEMU} ${TARGET_OUTPUT}/usr/bin/

		echo "debootstrap 1st"
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true debootstrap --foreign ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} "${TARGET_OUTPUT}" ${DEBIAN_MIRROR}

		echo "debootstrap 2nd"
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/debootstrap/debootstrap --second-stage"
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /bin/sh -c "/debootstrap/debootstrap --second-stage"
		fi

		echo "debootstrap 3rd"
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/bin/dpkg --configure -a"
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/bin/dpkg --configure -a"
		fi
	else
		echo "debootstrap"
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive debootstrap ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} "${TARGET_OUTPUT}" ${DEBIAN_MIRROR}
	fi

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

	#locale
	sed -i "s/# en_US.UTF-8/en_US.UTF-8/g" ${TARGET_OUTPUT}/etc/locale.gen
	sed -i "s/# ${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8 ]; then
		rm -rf ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8
	fi
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz ]; then
		gzip -dk ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz
	fi
	if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "/usr/sbin/locale-gen"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /bin/sh -c "/usr/sbin/locale-gen"
	fi
	echo "LANG=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/default/locale
	echo "LANGUAGE=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/default/locale
	echo "LC_ALL=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/default/locale

	#timezone
	if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
		ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime
		echo "${TARGET_TIMEZONE}" > ${TARGET_OUTPUT}/etc/timezone
	fi

	#skel
	cp -ar ${TARGET_OUTPUT}/etc/skel/. ${TARGET_OUTPUT}/root/

	#Mirror
	if [ "${TARGET_DISTRO}" = "debian" ]; then
		#echo "deb http://security.debian.org/ ${DEBIAN_DIST}/updates main" >> ${TARGET_OUTPUT}/etc/apt/sources.list
		#cat <<- EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
		#deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main contrib non-free
		## deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main contrib non-free

		#deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main contrib non-free
		## deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main contrib non-free

		##deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed-updates main contrib non-free
		### deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed-updates main contrib non-free

		##deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main contrib non-free
		### deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main contrib non-free

		#deb http://security.debian.org ${DEBIAN_DIST}/updates main contrib non-free
		## deb-src http://security.debian.org ${DEBIAN_DIST}/updates main contrib non-free
		#EOF
		cat <<- EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
		deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main
		# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main

		deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main
		# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main

		deb http://security.debian.org ${DEBIAN_DIST}/updates main
		# deb-src http://security.debian.org ${DEBIAN_DIST}/updates main
		EOF
	fi
	if [ "${TARGET_DISTRO}" = "ubuntu" ]; then
		#sed -i "s/ ${DEBIAN_DIST} main$/ ${DEBIAN_DIST} main universe/; p; s/ ${DEBIAN_DIST} main/ ${DEBIAN_DIST}-updates main/; p; s/ ${DEBIAN_DIST}-updates main/ ${DEBIAN_DIST}-security main/" ${TARGET_OUTPUT}/etc/apt/sources.list
		#cat <<- EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
		#deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main universe restricted multiverse
		## deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main universe restricted multiverse
		#
		#deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main universe restricted multiverse
		## deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main universe restricted multiverse
		#
		##deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed main universe restricted multiverse
		### deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed main universe restricted multiverse
		#
		##deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main universe restricted multiverse
		### deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main universe restricted multiverse
		#
		#deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main universe restricted multiverse
		## deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main universe restricted multiverse
		#EOF
		cat <<- EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
		deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main restricted universe
		# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main restricted universe

		deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main restricted universe
		# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main restricted universe

		deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main restricted universe
		# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main restricted universe
		EOF
	fi

	if strings "${TARGET_OUTPUT}/usr/bin/dpkg" | grep -q unsafe-io; then
		# force dpkg not to call sync() after package extraction (speeding up installs)
		cat > "${TARGET_OUTPUT}/etc/dpkg/dpkg.cfg.d/docker-apt-speedup" <<-'EOF'
		force-unsafe-io
		EOF
	fi
	
	if [ -d "${TARGET_OUTPUT}/etc/apt/apt.conf.d" ]; then
		# _keep_ us lean by effectively running "apt-get clean" after every install
		aptGetClean='"rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true";'
		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-clean" <<-EOF
		DPkg::Post-Invoke { ${aptGetClean} };
		APT::Update::Post-Invoke { ${aptGetClean} };

		Dir::Cache::pkgcache "";
		Dir::Cache::srcpkgcache "";
		EOF

		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-no-check-valid" <<-'EOF'
		Acquire::Check-Valid-Until "0";
		EOF

		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-no-languages" <<-'EOF'
		Acquire::Languages "none";
		EOF

		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-gzip-indexes" <<-'EOF'
		Acquire::GzipIndexes "true";
		Acquire::CompressionTypes::Order:: "gz";
		EOF

		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-gzip-indexes" <<-'EOF'
		Acquire::GzipIndexes "true";
		Acquire::CompressionTypes::Order:: "gz";
		EOF


		cat > "${TARGET_OUTPUT}/etc/apt/apt.conf.d/docker-recommends-suggests" <<-'EOF'
		APT::Install-Recommends "false";
		APT::Install-Suggests "false";
		EOF
	fi

	fn_make_common
}

fn_make_common() {
	fn_target_unmount
}

fn_update() {
	echo "Update"
	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

	#clear
	rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-*

	#qemu
	if [ ! -z "${TARGET_QEMU}" ]; then
		cp -f extra/${TARGET_QEMU} "${TARGET_OUTPUT}/usr/bin/"
	fi

	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8 ]; then
		rm -rf ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8
	fi
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz ]; then
		gzip -dk ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz
	fi

	#docker-run
	cp extra/docker-run ${TARGET_OUTPUT}/usr/local/bin/docker-run
	
	#docker-install
	if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
		cp -f extra/docker-install.arch ${TARGET_OUTPUT}/usr/local/bin/docker-install
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-sysusers ${TARGET_OUTPUT}/usr/local/bin/docker-tmpfiles
		#cp extra/docker-sysusers ${TARGET_OUTPUT}/usr/local/bin/
		#cp extra/docker-tmpfiles ${TARGET_OUTPUT}/usr/local/bin/
		mount -o bind ${TARGET_OUTPUT} ${TARGET_OUTPUT}
	elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=\(debian\|ubuntu\)" "${TARGET_OUTPUT}/etc/os-release")" ]; then
		cp -f extra/docker-install.deb ${TARGET_OUTPUT}/usr/local/bin/docker-install
	elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
		cp -f extra/docker-install.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-install
	fi
	rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-su
	#cp extra/docker-su ${TARGET_OUTPUT}/usr/local/bin/docker-su

	#docker-build
	if [ "${TARGET_ARCH}" = "armhf" ]; then
		cp -f extra/docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/"
		ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
		ln -sf docker-build-arm "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
		#if [ -e ${TARGET_OUTPUT}/lib/ld-musl-armhf.so.1 ]; then
		#	cp extra/docker-execve-check.armv7h.musl ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		#else
		#	cp extra/docker-execve-check.armv7h.glibc ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		#fi
		#cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		cp -f extra/docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/"
		ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
		ln -sf docker-build-aarch64 "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
		#if [ -e ${TARGET_OUTPUT}/lib/ld-musl-aarch64.so.1 ]; then
		#	cp extra/docker-execve-check.aarch64.musl ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		#else
		#	cp extra/docker-execve-check.aarch64.glibc ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		#fi
		#cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
	else
		cp -f extra/docker-build-x64 "${TARGET_OUTPUT}/usr/local/bin/docker-build"
		ln -sf docker-build "${TARGET_OUTPUT}/usr/local/bin/docker-build-start"
		ln -sf docker-build "${TARGET_OUTPUT}/usr/local/bin/docker-build-end"
		rm -rf ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
		#cp extra/docker-execve-check.sh ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
	fi

	#docker-adduser
	cp -f extra/docker-adduser ${TARGET_OUTPUT}/usr/local/bin/docker-adduser

	#docker-chown
	cp -f extra/docker-chown ${TARGET_OUTPUT}/usr/local/bin/docker-chown

	#su-exec
	#rm -rf ${TARGET_OUTPUT}/usr/local/bin/su-exec
	if [ "${TARGET_ARCH}" = "armhf" ]; then
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-armhf.so.1 ]; then
			cp extra/su-exec-musl-armv7h ${TARGET_OUTPUT}/usr/local/bin/su-exec
		else
			cp extra/su-exec-glibc-armv7h ${TARGET_OUTPUT}/usr/local/bin/su-exec
		fi
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-aarch64.so.1 ]; then
			cp extra/su-exec-musl-aarch64 ${TARGET_OUTPUT}/usr/local/bin/su-exec
		else
			cp extra/su-exec-glibc-aarch64 ${TARGET_OUTPUT}/usr/local/bin/su-exec
		fi
	else
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-x86_64.so.1 ]; then
			cp extra/su-exec-musl-x64 ${TARGET_OUTPUT}/usr/local/bin/su-exec
		else
			cp extra/su-exec-glibc-x64 ${TARGET_OUTPUT}/usr/local/bin/su-exec
		fi
	fi

	#goreman
	#rm -rf ${TARGET_OUTPUT}/usr/local/bin/goreman
	if [ "${TARGET_ARCH}" = "armhf" ]; then
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-armhf.so.1 ]; then
			cp extra/goreman-musl-armv7h ${TARGET_OUTPUT}/usr/local/bin/goreman
		else
			cp extra/goreman-glibc-armv7h ${TARGET_OUTPUT}/usr/local/bin/goreman
		fi
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-aarch64.so.1 ]; then
			cp extra/goreman-musl-aarch64 ${TARGET_OUTPUT}/usr/local/bin/goreman
		else
			cp extra/goreman-glibc-aarch64 ${TARGET_OUTPUT}/usr/local/bin/goreman
		fi
	else
		if [ -e ${TARGET_OUTPUT}/lib/ld-musl-x86_64.so.1 ]; then
			cp extra/goreman-musl-x64 ${TARGET_OUTPUT}/usr/local/bin/goreman
		else
			cp extra/goreman-glibc-x64 ${TARGET_OUTPUT}/usr/local/bin/goreman
		fi
	fi

	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8 ]; then
		rm -rf ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8
	fi
	if [ -e ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz ]; then
		gzip -dk ${TARGET_OUTPUT}/usr/share/i18n/charmaps/UTF-8.gz
	fi

	#archlinux term fix
	if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
		if [ ! -z "$(find ${TARGET_OUTPUT}/usr/share/terminfo/ 2> /dev/null | grep '_ADMIN_')" ]; then
			for t in ${TARGET_OUTPUT}/usr/share/terminfo/*_ADMIN_*
			do
				mv ${t} ${t/_ADMIN_*/}
			done
		fi
	fi

	#update
	prev_md5=
	post_md5=
	PATH_CHROOT=
	CHROOT_CMD=chroot
	if [ "${TARGET_UPDATE}" = "Y" ]; then
		if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
			prev_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/pacman/local 2> /dev/null | md5sum | cut -f 1 -d ' ')
			PATH_CHROOT="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl"
			if [ -e /usr/bin/arch-chroot ]; then
				CHROOT_CMD=arch-chroot
			fi
		elif [ -e "${TARGET_OUTPUT}/etc/os-release" -a ! -z "$(grep "ID=\(debian\|ubuntu\)" "${TARGET_OUTPUT}/etc/os-release")" ]; then
			prev_md5=$(tar -cf - ${TARGET_OUTPUT}/var/lib/dpkg/info 2> /dev/null | md5sum | cut -f 1 -d ' ')
			PATH_CHROOT="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
			rm -rf ${TARGET_OUTPUT}/var/lib/apt/lists/lock
		elif [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
			prev_md5=$(md5sum ${TARGET_OUTPUT}/lib/apk/db/installed | cut -f 1 -d ' ')
			PATH_CHROOT=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
		fi
		
		if [ "${TARGET_ARCH}" = "armhf" ] || [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "docker-install -r -u -c"
		else
			PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /bin/sh -c "docker-install -r -u -c"
		fi

		#archlinux update-ca-trust
		if [ -e "${TARGET_OUTPUT}/etc/arch-release" ]; then
			if [ ! -z "${TARGET_QEMU}" ]; then
				QEMU_EXECVE=1 PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "update-ca-trust"
			else
				PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /bin/sh -c "update-ca-trust"
			fi
		fi

		#alpinelinux update baselayout
		#if [ -e "${TARGET_OUTPUT}/etc/alpine-release" ]; then
			if [ ! -z "${TARGET_QEMU}" ]; then
				QEMU_EXECVE=1 PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /usr/bin/${TARGET_QEMU} -execve /bin/sh -c "apk --no-cache --allow-untrusted --quiet fetch alpine-base ; cat /alpine-base*.apk | tar -zxf - -C / etc/ ; rm -rf /alpine-base*.apk"
			else
				PATH="${PATH_CHROOT}" LANG=C LC_ALL=C ${CHROOT_CMD} "${TARGET_OUTPUT}" /bin/sh -c "apk --no-cache --allow-untrusted --quiet fetch alpine-base ; cat /alpine-base*.apk | tar -zxf - -C / etc/ ; rm -rf /alpine-base*.apk"
			fi
		#fi


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

	#clean
	#if [ -e "${TARGET_OUTPUT}/etc/os-release"  ]; then
	#	if [ ! -z "$(grep 'ID=\(debian\|ubuntu\)' "${TARGET_OUTPUT}/etc/os-release")" ]; then
	#		find ${TARGET_OUTPUT}/var -name \*.log -o -name \*-old -exec rm -rf "{}" \;
	#	fi
	#fi
	find ${TARGET_OUTPUT}/var -name \*.log -o -name \*-old -exec rm -rf "{}" \;

	rm -rf ${TARGET_OUTPUT}/qemu_*.core
}

fn_import() {
	echo "Import image"

	for id in $(docker ps -a -q -f ancestor=${TARGET_NAME}:${TARGET_TAG})
	do
		docker rm -f ${id}
	done
	for id in $(docker images -a -q ${TARGET_NAME}:${TAGET_TAG})
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
	if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" ] ; then
		#cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT ${shell}\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:${TARGET_TAG}"
		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT docker-run\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:${TARGET_TAG}"
	else
		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENTRYPOINT docker-run\" - ${TARGET_NAME}:${TARGET_TAG}"
	fi
	echo
	if [ "${DEBUG}" = "Y" ]; then
		echo "COMMAND : ${cmd}"
	fi
	eval ${cmd} #&> /dev/null
	echo Success.
	echo
}

fn_push() {
	echo "Push image"

	docker push ${TARGET_NAME}:${TARGET_TAG}
}

if [ "$(uname -m)" != "x86_64" ]; then
	echo "Not support host architecture (only for x86_64)"
	exit 1
fi

if [ -e /.dockerenv -a -e "${DOCKER_WORKDIR}" ]; then
	cd "${DOCKER_WORKDIR}"
fi

DEBUG=N

TARGET_DISTRO=
TARGET_ARCH=
TARGET_EDITION=
TARGET_OUTPUT=
TARGET_LOCALE=
TARGET_TIMEZONE=
TARGET_NAME=
TARGET_TAG=
TARGET_MAKE=
TARGET_MAKE_ONLY=
TARGET_UPDATE=
TARGET_IMPORT=
TARGET_PUSH=
TARGET_QEMU=

INCLUDE_PACKAGES=
EXCLUDE_PACKAGES=

EXTRA_ARGS=

QUIET=
VERBOSE=

while [[ ${#} > 0 ]]
do
	case "${1}" in
		-d|--distro) TARGET_DISTRO="${2}" ; shift 1 ;;
		-a|--arch|--archtecture) TARGET_ARCH="${2}" ; shift 1 ;;
		-e|--edition) TARGET_EDITION="${2}" ; shift 1 ;;
		-o|--out|--output) TARGET_OUTPUT="${2}" ; shift 1 ;;
		-l|--locale) TARGET_LOCALE="${2}" ; shift 1 ;;
		-z|--timezone) TARGET_TIMEZONE="${2}" ; shift 1 ;;
		--include) INCLUDE_PACKAGES="${2}" ; shift 1 ;;
		--exclude) EXCLUDE_PACKAGES="${2}" ; shift 1 ;;
		-n|--name) TARGET_NAME="${2/:*/}" ; TARGET_TAG="${2/*:/}" ; shift 1 ;;
		-u|--update) TARGET_UPDATE="Y" ;;
		-i|--import) TARGET_IMPORT="Y" ;;
		-m|--make) TARGET_MAKE="Y" ;;
		-mo) TARGET_MAKE="Y" ; TARGET_MAKE_ONLY="Y" ;;
		-p|--push) TARGET_PUSH="Y" ;;
		-q|--quiet) QUIET="Y" ;;
		-v|--verbose) VERBOSE="Y" ;;
		-h|--help) fn_usage ;;
	   	*) EXTRA_ARGS+=(${1}) ;;
	esac
	shift
done

#create dist.img
if [ ! -e dist ]; then
	mkdir -p dist
fi
if [ ! -e dist.img ]; then
	dd if=/dev/zero of=dist.img bs=1G count=10 skip=10
	mkfs.ext4 -F dist.img
	mount -o loop dist.img dist
	touch dist/img
elif [ ! -e dist/img ]; then
	mount -o loop dist.img dist
fi

if [ ! -e dist/img ]; then
	echo "Errof dist.img"
	exit 1
fi

#set default
#TARGET_DISTRO="${TARGET_DISTRO:-arch}"
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
	if [ ! -z "${TARGET_TAG}" ]; then
		if [ -z "${TARGET_EDITION}" ]; then
			TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}-${TARGET_TAG}
		else
			TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}-${TARGET_EDITION}-${TARGET_TAG}
		fi
	else
		if [ -z "${TARGET_EDITION}" ]; then
			TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}
		else
			TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}-${TARGET_EDITION}
		fi
	fi
	TARGET_OUTPUT="dist/${TARGET_OUTPUT}"
	TARGET_OUTPUT=$(realpath ${TARGET_OUTPUT})
fi
TARGET_LOCALE=${TARGET_LOCALE:-ko_KR.UTF-8}
TARGET_TIMEZONE=${TARGET_TIMEZONE:-Asia/Seoul}
if [ -z "${TARGET_EDITION}" ]; then
	TARGET_NAME=${TARGET_NAME:-forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base}
else
	TARGET_NAME=${TARGET_NAME:-forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base-${TARGET_EDITION}}
fi
TARGET_TAG=${TARGET_TAG:-latest}
if [ -e "${TARGET_OUTPUT}" ]; then
	TARGET_MAKE=${TARGET_MAKE:-N}
else
	TARGET_MAKE=Y
fi
if [ "${TARGET_MAKE_ONLY}" != "Y" -a "${TARGET_MAKE}" = "Y" -a -z "${TARGET_UPDATE}" ]; then
	TARGET_UPDATE=Y
else
	TARGET_UPDATE=${TARGET_UPDATE:-N}
fi
TARGET_IMPORT=${TARGET_IMPORT:-N}
TARGET_PUSH=${TARGET_PUSH:-N}
if [ "${TARGET_PUSH}" = "Y" ]; then
	TARGET_IMPORT=Y
fi
if [ "${TARGET_ARCH}" = "armhf" ]; then
	TARGET_QEMU=qemu-arm-static
elif [ "${TARGET_ARCH}" = "aarch64" ]; then
	TARGET_QEMU=qemu-aarch64-static
fi
QUIET=${QUIET:-N}
if [ "${QUIET}" = "Y" ]; then
	VERBOSE=${VERBOSE:-N}
else
	VERBOSE=${VERBOSE:-Y}
fi

#confirm
if [ "${DEBUG}" = "Y" -o "${VERBOSE}" = "Y" ]; then
	echo "TARGET_DISTRO=${TARGET_DISTRO}"
	echo "TARGET_ARCH=${TARGET_ARCH}"
	if [ ! -z "${TARGET_EDITION}" ]; then
		echo "TARGET_EDITION=${TARGET_EDITION}"
	fi
	echo "TARGET_OUTPUT=${TARGET_OUTPUT}"
	echo "TARGET_LOCALE=${TARGET_LOCALE}"
	echo "TARGET_TIMEZONE=${TARGET_TIMEZONE}"
	echo "TARGET_NAME=${TARGET_NAME}"
	echo "TARGET_TAG=${TARGET_TAG}"
	echo "TARGET_OUTPUT=$(basename "${TARGET_OUTPUT}")"
	echo "TARGET_MAKE=${TARGET_MAKE}"
	echo "TARGET_UPDATE=${TARGET_UPDATE}"
	echo "TARGET_IMPORT=${TARGET_IMPORT}"
	echo "TARGET_PUSH=${TARGET_PUSH}"
	echo "TARGET_QEMU=${TARGET_QEMU}"
	echo ""
	echo "INCLUDE_PACKAGES=${INCLUDE_PACKAGES}"
	echo "EXCLUDE_PACKAGES=${EXCLUDE_PACKAGES}"
	echo ""
	echo "EXTRA_ARGS=${EXTRA_ARGS}"
	echo ""
	if [ "${QUIET}" != "Y" ]; then
		echo "Do you want to do this now? [y|N]"
		read -r confirm
		if [[ ${confirm} =~ ^([yY][eE][sS]|[yY])$ ]]; then
			echo ""
		else
			fn_usage
		fi
	fi
fi

##binfmt
#if [ ! -e /.dockerenv ]; then
#	if [ "${TARGET_ARCH}" = "armhf" -o "${TARGET_ARCH}" = "aarch64" ]; then
#		#binfmt
#		if [ ! -e /proc/sys/fs/binfmt_misc/register ]; then
#			/bin/mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
#		fi
#		if [ -e /proc/sys/fs/binfmt_misc/register ]; then
#			if [ "${TARGET_ARCH}" = "armhf" ]; then
#				if [ ! -e /usr/bin/qemu-arm-static ]; then
#					cp extra/qemu-arm-static /usr/bin/qemu-arm-static
#				fi
#				if [ ! -e /proc/sys/fs/binfmt_misc/arm -a -e /usr/bin/qemu-arm-static ]; then
#					echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register
#				fi
#			fi
#
#			if [ "${TARGET_ARCH}" = "aarch64" ]; then
#				if [ ! -e /usr/bin/qemu-aarch64-static ]; then
#					cp extra/qemu-aarch64-static /usr/bin/qemu-aarch64-static
#				fi
#				if [ ! -e /proc/sys/fs/binfmt_misc/aarch64 -a -e /usr/bin/qemu-aarch64-static ]; then
#					echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:' > /proc/sys/fs/binfmt_misc/register
#				fi
#			fi
#		fi
#	fi
#fi

#prepare
fn_target_unmount

#Check arch linux
if [ "${TARGET_DISTRO}" = "arch" -a "${TARGET_MAKE}" != "Y" ]; then
	if [ -z "$(ls ${TARGET_OUTPUT}/etc/ca-certificates/extracted)" ]; then
		TARGET_MAKE=Y
	fi
fi

#Make
if [ "${TARGET_MAKE}" = "Y" ]; then
	if [ -e /.dockerenv -a -e /etc/alpine-release ]; then
		rm -rf "${TARGET_OUTPUT}" || (echo "Cannot remove ${TARGET_OUTPUT}" ; exit 1)
		mkdir -p "${TARGET_OUTPUT}" || (echo "Cannot create ${TARGET_OUTPUT}" ; exit 1)
		chmod 755 ${TARGET_OUTPUT}

		eval fn_make_${TARGET_DISTRO}
	else
		if [ -e /.dockerenv ]; then
			echo "Cannot execute in docker (2)"
			exit 1
		else
			tgt="$(echo "${TARGET_OUTPUT}" | sed -e "s#$(realpath "$(pwd)")#/build#g")"
			fn_run_docker -d "${TARGET_DISTRO}" -a "${TARGET_ARCH}" $([ ! -z "${TARGET_EDITION}" ] && echo "-e ${TARGET_EDITION}") -o "${tgt}" -l "${TARGET_LOCALE}" -z "${TARGET_TIMEZONE}" $([ ! -z "${INCLUDE_PACKAGES}" ] && echo "--include \"${INCLUDE_PACKAGES}\"") $([ ! -z "${EXCLUDE_PACKAGES}" ] && echo "--exclude \"${EXCLUDE_PACKAGES}\"") -n "${TARGET_NAME}:${TARGET_TAG}" -m -u -q ${EXTRA_ARGS[*]}
			TARGET_UPDATE=N
		fi
	fi
fi

#Update
if [ "${TARGET_UPDATE}" = "Y" ]; then
	if [ -e /.dockerenv -a -e /etc/alpine-release ]; then
		eval fn_update
	else
		if [ -e /.dockerenv ]; then
			echo "Cannot execute in docker (3)"
			exit 1
		else
			tgt="$(echo "${TARGET_OUTPUT}" | sed -e "s#$(realpath "$(pwd)")#/build#g")"
			fn_run_docker -d "${TARGET_DISTRO}" -a "${TARGET_ARCH}" $([ ! -z "${TARGET_EDITION}" ] && echo "-e ${TARGET_EDITION}") -o "${tgt}" -l "${TARGET_LOCALE}" -z "${TARGET_TIMEZONE}" $([ ! -z "${INCLUDE_PACKAGES}" ] && echo "--include \"${INCLUDE_PACKAGES}\"") $([ ! -z "${EXCLUDE_PACKAGES}" ] && echo "--exlcude \"${EXCLUDE_PACKAGES}\"") -n "${TARGET_NAME}:${TARGET_TAG}" -u -q ${EXTRA_ARGS[*]}
		fi
	fi
fi

#clean
rm -rf ${TARGET_OUTPUT}/qemu_*.core

#dockerenv
if [ -e /.dockerenv ]; then
	if [ "${TARGET_MAKE}" != "Y" -a "${TARGET_UPDATE}" != "Y" ]; then
		echo "Cannot exeucte in docker (4)"
	fi
	exit
fi

#Import
if [ ! -e /.dockerenv -a "${TARGET_IMPORT}" = "Y" ]; then
	fn_import
fi

#Push
if [ ! -e /.dockerenv -a "${TARGET_PUSH}" = "Y" ]; then
	fn_push
fi

if [ -e dist/img ]; then
	umount dist
fi

