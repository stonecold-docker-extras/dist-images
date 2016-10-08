#!/usr/bin/env bash

if [ "${UID}" -ne 0 ]; then
	sudo "${0}" $*
	exit $?
fi

LANG="C"
LC_ALL="C"

usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-t type] [-l locale] [-z timezone] [-c] [-r] [-i include packages] [-e exclude pacakges]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),x86(i686),armv5(arm),armv6h,armv7h,aarch64 (default : x64)"
	echo "          [-o output] : output dir (default : distro_archtecture)"
	echo "          [-t type] : docker,native (default : docker)"
	echo "          [-l locale] : locale (default : ko_KR.UTF-8)"
	echo "          [-z timezone] : timezone (default : Asia/Seoul)"
	echo "          [-c] : compress image (default : false)"
	echo "          [-r] : remove rootdir (default : false)"
	echo "          [-i include pacakges] : include pacakges (default : null)"
	echo "          [-e exclude pacakges] : exclude pacakges (default : null)"
	exit 1
}

makearch() {
	if ! pacstrap -h &>/dev/null ; then
		echo "Could not find pacstrap. Run pacman -S arch-install-scripts"
		exit 1
	fi

	if ! arch-chroot -h &>/dev/null ; then
		echo "Could not find arch-chroot. Run pacman -S arch-install-scripts"
		exit 1
	fi

	echo -e "Y\nY" | pacman -Scc

	local PACMAN_MIRRORLIST=
	local PACMAN_EXTRA_PKGS=
	local ARCH_KEYRING=

	local ARCH_ARCH=${TARGET_ARCH}
	ARCH_ARCH=${ARCH_ARCH/x86/i686}
	ARCH_ARCH=${ARCH_ARCH/x64/x86_64}
	ARCH_ARCH=${ARCH_ARCH/armv5/arm}
	echo ${ARCH_ARCH}

	if [ "${TARGET_ARCH}" == "armv5" -o "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" -o "${TARGET_ARCH}" == "aarch64" ]; then
		#PACMAN_MIRRORLIST='Server = http://mirror.archlinuxarm.org/$arch/$repo'
		PACMAN_MIRRORLIST='Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo'
		PACMAN_EXTRA_PKGS='archlinuxarm-keyring'
		ARCH_KEYRING="archlinuxarm"
	else
		PACMAN_MIRRORLIST='Server = http://ftp.kaist.ac.kr/ArchLinux/$repo/os/$arch'
		PACMAN_EXTRA_PKGS=''
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
	if [ "${TARGET_ARCH}" == "x64" ]; then
	cat << EOF >> "${PACMAN_CONF}"
[multilib]
${PACMAN_MIRRORLIST}
EOF
	fi
	if [ "${TARGET_ARCH}" == "armv5" -o "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" -o "${TARGET_ARCH}" == "aarch64" ]; then
		cat << EOF >> "${PACMAN_CONF}"
[alarm]
${PACMAN_MIRRORLIST}
[aur]
${PACMAN_MIRRORLIST}
EOF
	fi

	#qemu
	#pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} filesystem || (echo "pacstrap failed : filesystem" ; exit 1)
	if [ "${TARGET_ARCH}" == "armv5" -o "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		if [ -e extra/qemu-arm-static ]; then
			cp extra/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e qemu-arm-static ]; then
			cp qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e /usr/bin/qemu-arm-static ]; then
			cp /usr/bin/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		fi
	fi
	if [ "${TARGET_ARCH}" == "aarch64" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		if [ -e extra/qemu-aarch64-static ]; then
			cp extra/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e qemu-aarch64-static ]; then
			cp qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e /usr/bin/qemu-aarch64-static ]; then
			cp /usr/bin/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		fi
	fi

	#pacstrap
	#pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} pacman || (echo "pacstrap failed : pacman" ; exit 1)
	#pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} bash bzip2 coreutils diffutils file findutils gawk gettext glibc grep gzip less licenses perl procps-ng psmisc sed shadow systemd tar texinfo util-linux which ${PACMAN_EXTRA_PKGS}
	#pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} bash bzip2 coreutils diffutils file findutils gawk gettext glibc grep gzip inetutils less licenses perl procps-ng psmisc sed shadow systemd tar texinfo util-linux which ${PACMAN_EXTRA_PKGS} || (echo "pacstrap failed : packages" ; exit 1)
	pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} bash bzip2 coreutils diffutils e2fsprogs filesystem findutils gettext glibc grep gzip less pacman perl procps-ng sed shadow systemd ${PACMAN_EXTRA_PKGS} || (echo "pacstrap failed : packages" ; exit 1)

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#locale
	sed -i "s/#${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen || (echo "config failed : locale" ; exit 1)

	#timezone
	if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
		ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime || (echo "config failed : timezone" ; exit 1)
	fi

	#skel
	cp -ar ${TARGET_OUTPUT}/etc/skel/. ${TARGET_OUTPUT}/root/ || (echo "config failed : skel" ; exit 1)

	#basic config
	echo "${PACMAN_MIRRORLIST}" > ${TARGET_OUTPUT}/etc/pacman.d/mirrorlist || (echo "config failed : mirrorlist" ; exit 1)
	sed -i "s/\(Architecture =\) auto/\1 ${ARCH_ARCH}/g" ${TARGET_OUTPUT}/etc/pacman.conf || (echo "config failed : pacman.conf" ; exit 1)
	sed -i "s/#\(NoUpgrade   =\)/\1 \/etc\/pacman.d\/mirrorlist/g" ${TARGET_OUTPUT}/etc/pacman.conf || (echo "config failed : pacman.conf" ; exit 1)
	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "pacman-key --init; pacman-key --populate ${ARCH_KEYRING}; pkill gpg-agent; locale-gen" || (echo "config failed : chroot" ; exit 1)
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "pacman-key --init; pacman-key --populate ${ARCH_KEYRING}; pkill gpg-agent; locale-gen" || (echo "config failed : chroot" ; exit 1)
	else
		arch-chroot ${TARGET_OUTPUT} /bin/sh -c "pacman-key --init; pacman-key --populate ${ARCH_KEYRING}; pkill gpg-agent; locale-gen" || (echo "config failed : chroot" ; exit 1)
	fi

	#x64 multilib
	#if [ "${TARGET_ARCH}" == "x64" ]; then
	#	sed -i -e "/^#\[multilib\]/{N; s/#\(\[multilib\]\)\n#\(.*\)$/\1\n\2/g}" ${TARGET_OUTPUT}/etc/pacman.conf || (echo "config failed : pacman.conf" ; exit 1)
	#	arch-chroot ${TARGET_OUTPUT} /bin/sh -c "pacman -Suy ; pacman -Rdd --noconfirm gcc-libs ; pacman -S --noconfirm --quiet --asdeps gcc-libs-multilib" || (echo "config failed : multilib" ; exit 1)
	#fi

	#yaourt
	if [ -e extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz -a -e extra/yaourt-*-any.pkg.tar.xz ]; then
		cp extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz ${TARGET_OUTPUT}/
		cp extra/yaourt-*-any.pkg.tar.xz ${TARGET_OUTPUT}/
		if [ "${TARGET_UPDATE}" = "Y" ]; then
			if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
				QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "pacman -U --noconfirm --asdeps /package-query-*; pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz" || (echo "config failed : yaourt" ; exit 1)
			elif [ "${TARGET_ARCH}" = "aarch64" ]; then
				QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "pacman -U --noconfirm --asdeps /package-query-*; pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz" || (echo "config failed : yaourt" ; exit 1)
			else
				arch-chroot ${TARGET_OUTPUT} /bin/sh -c "pacman -U --noconfirm --asdeps /package-query-*; pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz" || (echo "config failed : yaourt" ; exit 1)
			fi
		fi
		rm -rf ${TARGET_OUTPUT}/*.pkg.tar.xz
	fi

	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "echo -e 'Y\nY' | pacman -Scc" || (echo "config failed : pacman -Scc" ; exit 1)
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 arch-chroot ${TARGET_OUTPUT} /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "echo -e 'Y\nY' | pacman -Scc" || (echo "config failed : pacman -Scc" ; exit 1)
	else
		arch-chroot ${TARGET_OUTPUT} /bin/sh -c "echo -e 'Y\nY' | pacman -Scc" || (echo "config failed : pacman -Scc" ; exit 1)
	fi

	rm -rf "${PACMAN_CONF}"

	rm -rf ${TARGET_OUTPUT}/var/cache/pacman/pkg/*
	rm -rf ${TARGET_OUTPUT}/var/lib/pacman/sync/*
	rm -rf ${TARGET_OUTPUT}/tmp/yaourt*

	commonpostwork
}

makealpine() {
	if [ "${TARGET_ARCH}" == "armv5" ]; then
		echo "Not support ubuntu architecture"
		exit 1
	fi

	local ALPINE_DIST=edge
	local ALPINE_MIRROR=http://dl-cdn.alpinelinux.org/alpine

	local ALPINE_ARCH=${TARGET_ARCH}
	ALPINE_ARCH=${ALPINE_ARCH/x64/x86_64}
	ALPINE_ARCH=${ALPINE_ARCH/armv6h/armhf}
	ALPINE_ARCH=${ALPINE_ARCH/armv7h/armhf}
	ALPINE_ARCH=${ALPINE_ARCH/aarch64/aarch64}

	local APK_VERSION="$(curl -sSL ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/APKINDEX.tar.gz | tar -Oxz | grep --text '^P:apk-tools-static$' -A1 | tail -n1 | cut -d: -f2)"

	curl -sSL ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/apk-tools-static-${APK_VERSION}.apk | tar -xz -C ${TARGET_OUTPUT} sbin/apk.static 

	if [ "${TARGET_ARCH}" == "armv5" -o "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		if [ -e extra/qemu-arm-static ]; then
			cp extra/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e qemu-arm-static ]; then
			cp qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e /usr/bin/qemu-arm-static ]; then
			cp /usr/bin/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
		fi
	fi
	if [ "${TARGET_ARCH}" == "aarch64" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		if [ -e extra/qemu-aarch64-static ]; then
			cp extra/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e qemu-aarch64-static ]; then
			cp qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		elif [ -e /usr/bin/qemu-aarch64-static ]; then
			cp /usr/bin/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
		fi
	fi

	${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --update-cache --allow-untrusted --root ${TARGET_OUTPUT} --initdb add alpine-base 

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#mirror
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/main" > ${TARGET_OUTPUT}/etc/apk/repositories
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/community" >> ${TARGET_OUTPUT}/etc/apk/repositories

	#timezone
	echo "${TARGET_TIMEZONE}" > ${TARGET_OUTPUT}/etc/TZ
	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "apk update ; setup-timezone -z Asia/Seoul"
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "apk update ; setup-timezone -z Asia/Seoul"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chroot "${TARGET_OUTPUT}" /bin/sh -c "apk update ; setup-timezone -z Asia/Seoul"
	fi

	rm -rf ${TARGET_OUTPUT}/sbin/apk.static
	rm -rf ${TARGET_OUTPUT}/var/cache/apk/*

	commonpostwork
}

makedebian() {
	local DEBIAN_DIST=jessie
	local DEBIAN_MIRROR=http://ftp.kr.debian.org/debian
	local DEBIAN_EXTRA=locales

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x86/i386}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv5/armel}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv6h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	makedebiancommon "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

makeubuntu() {
	if [ "${TARGET_ARCH}" == "armv5" ]; then
		echo "Not support ubuntu architecture"
		exit 1
	fi

	local DEBIAN_DIST=xenial
	local DEBIAN_MIRROR=
	if [ "${TARGET_ARCH}" == "x64" -o "${TARGET_ARCH}" == "x86" ]; then
		DEBIAN_MIRROR=http://kr.archive.ubuntu.com/ubuntu
	else
		DEBIAN_MIRROR=http://ports.ubuntu.com/ubuntu-ports
	fi
	local DEBIAN_EXTRA=

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x86/i386}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv5/armel}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv6h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	makedebiancommon "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

makedebiancommon() {
	if ! debootstrap --help &>/dev/null ; then
		echo "Could not find debootstrap. Run pacman -S debootstrap"
		exit 1
	fi

	#DEBIAN_FRONTEND=noninteractive
	#alias apt-get="apt-get -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true"

	local DEBIAN_DIST="${1}"
	local DEBIAN_MIRROR="${2}"
	local DEBIAN_EXTRA=("${3}")
	local DEBIAN_ARCH=("${4}")
	local DEBIAN_OPTION=("--variant=minbase")
	if [ ! -z "${DEBIAN_EXTRA}" ]; then
		DEBIAN_OPTION=("${DEBIAN_OPTION[@]}" "--include=${DEBIAN_EXTRA}")
	fi

	DEBIAN_OPTION=("--arch=${DEBIAN_ARCH}" "${DEBIAN_OPTION[@]}")

	if [ "${TARGET_ARCH}" == "x64" -o "${TARGET_ARCH}" == "x86" ]; then
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive debootstrap ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} ${TARGET_OUTPUT} ${DEBIAN_MIRROR} || (echo "debootstrap failed" ; exit 1)
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive debootstrap --foreign ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} ${TARGET_OUTPUT} ${DEBIAN_MIRROR} || (echo "debootstrap failed : step 1" ; exit 1)

		if [ "${TARGET_ARCH}" == "armv5" -o "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" ]; then
			mkdir -p ${TARGET_OUTPUT}/usr/bin
			if [ -e extra/qemu-arm-static ]; then
				cp extra/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
			elif [ -e qemu-arm-static ]; then
				cp qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
			elif [ -e /usr/bin/qemu-arm-static ]; then
				cp /usr/bin/qemu-arm-static ${TARGET_OUTPUT}/usr/bin/
			fi
		fi
		if [ "${TARGET_ARCH}" == "aarch64" ]; then
			mkdir -p ${TARGET_OUTPUT}/usr/bin
			if [ -e extra/qemu-aarch64-static ]; then
				cp extra/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
			elif [ -e qemu-aarch64-static ]; then
				cp qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
			elif [ -e /usr/bin/qemu-aarch64-static ]; then
				cp /usr/bin/qemu-aarch64-static ${TARGET_OUTPUT}/usr/bin/
			fi
		fi

		if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "/debootstrap/debootstrap --second-stage" || (echo "debootstrap failed : step2" ; exit 1)
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "dpkg --configure -a" || (echo "debootstrap failed : step3" ; exit 1)
		elif [ "${TARGET_ARCH}" = "aarch64" ]; then
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "/debootstrap/debootstrap --second-stage" || (echo "debootstrap failed : step2" ; exit 1)
			QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "dpkg --configure -a" || (echo "debootstrap failed : step3" ; exit 1)
		else
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /debootstrap/debootstrap --second-stage || (echo "debootstrap failed : step2" ; exit 1)
			PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" dpkg --configure -a || (echo "debootstrap failed : step3" ; exit 1)
		fi

	fi

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#locale
	sed -i "s/# ${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen
	echo "LANG=${TARGET_LOCALE}" >> /etc/default/locale
	echo "LC_ALL=${TARGET_LOCALE}" >> /etc/default/locale

	#timezone
	if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
		ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime
	fi

	#skel
	cp -ar ${TARGET_OUTPUT}/etc/skel/. ${TARGET_OUTPUT}/root/

	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "locale-gen"
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "locale-gen"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" /bin/sh -c "locale-gen"
	fi

	#echo 'force-unsafe-io' > ${TARGET_OUTPUT}/etc/dpkg/dpkg.cfg.d/0-force-unsafe-io

	#echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-clean
	#echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-clean
	#echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-clean

	#echo 'Acquire::Languages "none";' > ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-no-languages

	#echo 'Acquire::GzipIndexes "true";' > ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-gzip-indexes
	#echo 'Acquire::CompressionTypes::Order:: "gz";' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-gzip-indexes

	#echo 'APT::Install-Recommends 0;' > ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-norecommends
	#echo 'APT::Install-Suggests 0;' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/o-norecommends

	#echo 'APT::Get::Assume-Yes "true";' > ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-assume-yes
	#echo 'APT::Get::allow-downgrades "true";' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-assume-yes
	#echo 'APT::Get::allow-remove-essential "true";' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-assume-yes
	#echo 'APT::Get::allow-change-held-packages "true";' >> ${TARGET_OUTPUT}/etc/apt/apt.conf.d/0-assume-yes

	#Mirror
	if [ "${TARGET_DISTRO}" == "debian" ]; then
		#sed -i "p; s/ ${DEBIAN_DIST} main$/ ${DEBIAN_DIST}-updates main/" ${TARGET_OUTPUT}/etc/apt/sources.list
		#echo "deb http://security.debian.org/ ${DEBIAN_DIST}/updates main" >> ${TARGET_OUTPUT}/etc/apt/sources.list
		cat << EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main
deb http://security.debian.org ${DEBIAN_DIST}/updates main
EOF
	fi
	if [ "${TARGET_DISTRO}" == "ubuntu" ]; then
		#sed -i "s/ ${DEBIAN_DIST} main$/ ${DEBIAN_DIST} main universe/; p; s/ ${DEBIAN_DIST} main/ ${DEBIAN_DIST}-updates main/; p; s/ ${DEBIAN_DIST}-updates main/ ${DEBIAN_DIST}-security main/" ${TARGET_OUTPUT}/etc/apt/sources.list
		cat << EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main restricted
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main restricted

## Major bug fix updates produced after the final release of the
## distribution.
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main restricted
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main restricted

## Uncomment the following two lines to add software from the 'universe'
## repository.
## N.B. software from this repository is ENTIRELY UNSUPPORTED by the Ubuntu
## team. Also, please note that software in universe WILL NOT receive any
## review or updates from the Ubuntu security team.
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} universe
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} universe
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates universe
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates universe

## N.B. software from this repository may not have been tested as
## extensively as that contained in the main release, although it includes
## newer versions of some applications which may provide useful features.
## Also, please note that software in backports WILL NOT receive any review
## or updates from the Ubuntu security team.
# deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main restricted
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main restricted

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main restricted
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main restricted
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security universe
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security universe
# deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security multiverse
EOF
	fi

	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "armv6h" -o "${TARGET_ARH}" = "arm" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /usr/bin/qemu-arm-static -execve -0 /bin/sh /bin/sh -c "apt-get update -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true && apt-get dist-upgrade -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get install apt-utils -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get autoremove --purge -y ; apt-get autoclean -y ; apt-get clean ; find /var/lib/apt -type f -exec rm \"{}\" \\;"
	elif [ "${TARGET_ARCH}" = "aarch64" ]; then
		QEMU_EXECVE=1 PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /usr/bin/qemu-aarch64-static -execve -0 /bin/sh /bin/sh -c "apt-get update -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true && apt-get dist-upgrade -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get install apt-utils -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get autoremove --purge -y ; apt-get autoclean -y ; apt-get clean ; find /var/lib/apt -type f -exec rm \"{}\" \\;"
	else
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot "${TARGET_OUTPUT}" /bin/sh -c "apt-get update -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true && apt-get dist-upgrade -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get install apt-utils -y -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true ; apt-get autoremove --purge -y ; apt-get autoclean -y ; apt-get clean ; find /var/lib/apt -type f -exec rm \"{}\" \\;"
	fi
	
	commonpostwork
}

commonpostwork() {
	if [ "${TARGET_TYPE}" == "docker" ]; then
		# udev doesn't work in containers, rebuild /dev
		local TARGET_DEV=${TARGET_OUTPUT}/dev
		rm -rf ${TARGET_DEV}
		mkdir -p ${TARGET_DEV}
		mknod -m 666 ${TARGET_DEV}/null c 1 3
		mknod -m 666 ${TARGET_DEV}/zero c 1 5
		mknod -m 666 ${TARGET_DEV}/random c 1 8
		mknod -m 666 ${TARGET_DEV}/urandom c 1 9
		mkdir -m 755 ${TARGET_DEV}/pts
		mkdir -m 1777 ${TARGET_DEV}/shm
		mknod -m 666 ${TARGET_DEV}/tty c 5 0
		mknod -m 600 ${TARGET_DEV}/console c 5 1
		mknod -m 666 ${TARGET_DEV}/tty0 c 4 0
		mknod -m 666 ${TARGET_DEV}/full c 1 7
		mknod -m 600 ${TARGET_DEV}/initctl p
		mknod -m 666 ${TARGET_DEV}/ptmx c 5 2
		ln -sf /proc/self/fd ${TARGET_DEV}/fd

		local qemu=
		if [ "${TARGET_ARCH}" == "armv5" -a "${TARGET_ARCH}" == "armv6h" -o "${TARGET_ARCH}" == "armv7h" ]; then
			qemu=qemu-arm-static
		elif [ "${TARGET_ARCH}" == "aarch64" ]; then
			qemu=qemu-aarch64-static
		fi
		if [ ! -z "${qemu}" ]; then
			if [ ! -e "${TARGET_OUTPUT}/usr/bin/${qemu}" ]; then
				mkdir -p ${TARGET_OUTPUT}/usr/bin
				if [ -e ${qemu} ]; then
					cp ${qemu} ${TARGET_OUTPUT}/usr/bin/
				fi
				if [ -e /usr/bin/${qemu} ]; then
					cp /usr/bin/${qemu} ${TARGET_OUTPUT}/usr/bin/
				fi
			fi

			if [ "${qemu}" == "qemu-arm-static" ]; then
				cp extra/docker-build-arm ${TARGET_OUTPUT}/usr/local/bin/
				chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-build-arm
				chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-build-arm
				ln -s docker-build-arm ${TARGET_OUTPUT}/usr/local/bin/docker-build-start
				ln -s docker-build-arm ${TARGET_OUTPUT}/usr/local/bin/docker-build-end
			fi
			if [ "${qemu}" == "qemu-aarch64-static" ]; then
				cp extra/docker-build-aarch64 ${TARGET_OUTPUT}/usr/local/bin/
				chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-build-aarch64
				chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-build-aarch64
				ln -s docker-build-aarch64 ${TARGET_OUTPUT}/usr/local/bin/docker-build-start
				ln -s docker-build-aarch64 ${TARGET_OUTPUT}/usr/local/bin/docker-build-end
			fi
		else
			cp extra/docker-build-start ${TARGET_OUTPUT}/usr/local/bin/docker-build-start
			chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-build-start
			chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-build-start

			cp extra/docker-build-end ${TARGET_OUTPUT}/usr/local/bin/docker-build-end
			chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-build-end
			chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-build-end
		fi

		if [ "${TARGET_DISTRO}" == "arch" ]; then
			cp extra/docker-install.arch ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-install
		fi
		if [ "${TARGET_DISTRO}" == "alpine" ]; then
			cp extra/docker-install.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-install
			if [ ! -z "${qemu}" ]; then
				cp extra/docker-execve-check.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
				chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
				chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check
				cp extra/docker-execve-check.sh.alpine ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
				chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
				chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-execve-check.sh
			fi
		fi
		if [ "${TARGET_DISTRO}" == "debian" -o "${TARGET_DISTRO}" == "ubuntu" ]; then
			cp extra/docker-install.deb ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chown 0.0 ${TARGET_OUTPUT}/usr/local/bin/docker-install
			chmod 755 ${TARGET_OUTPUT}/usr/local/bin/docker-install
		fi

		#if [ "${TARGET_DISTRO}" == "arch" ]; then
		#	if [ ! -z "${qemu}" ]; then
		#		tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change "ENV LANG=${TARGET_LOCALE}" --change "ENV LC_ALL=${TARGET_LOCALE}" --change "ENV TERM=xterm" --change "USER root" --change "CMD /bin/bash --login" --change "ENV QEMU_EXECVE=1" - ${TARGET_NAME}:latest
		#	else
		#		tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change "ENV LANG=${TARGET_LOCALE}" --change "ENV LC_ALL=${TARGET_LOCALE}" --change "ENV TERM=xterm" --change "USER root" --change "CMD /bin/bash --login" - ${TARGET_NAME}:latest
		#	fi
		#else
		#	if [ ! -z "${qemu}" ]; then
		#		tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change "ENV LANG=${TARGET_LOCALE}" --change "ENV LC_ALL=${TARGET_LOCALE}" --change "ENV TERM=xterm" --change "USER root" --change "CMD /bin/bash --login" --change "ENV QEMU_EXECVE=1" - ${TARGET_NAME}:latest
		#	else
		#		tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change "ENV LANG=${TARGET_LOCALE}" --change "ENV LC_ALL=${TARGET_LOCALE}" --change "ENV TERM=xterm" --change "USER root" --change "CMD /bin/bash --login" - ${TARGET_NAME}:latest
		#	fi
		#fi
		#docker run --rm -t ${TARGET_NAME}:latest echo Success.

		#local cmd=
		#if [ "${TARGET_DISTRO}" != "alpine" ]; then
		#	if [ ! -z "${qemu}" ]; then
		#		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/bash --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		#	else
		#		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV LANG=${TARGET_LOCALE}\" --change \"ENV LC_ALL=${TARGET_LOCALE}\" --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/bash --login\" - ${TARGET_NAME}:latest"
		#	fi
		#else
		#	if [ ! -z "${qemu}" ]; then
		#		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/sh --login\" --change \"ENV QEMU_EXECVE=1\" - ${TARGET_NAME}:latest"
		#	else
		#		cmd="tar --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c . | docker import --change \"ENV TERM=xterm\" --change \"USER root\" --change \"CMD /bin/sh --login\" - ${TARGET_NAME}:latest"
		#	fi
		#fi
		#echo
		#echo "COMMAND : ${cmd}"
		#eval ${cmd}
		#echo
		#echo Success.
		#echo

		#import
		local cmd=
		local shell=
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

	if [ "${TARGET_COMPRESS}" == "Y" ]; then
		tar -Jcf ${TARGET_OUTPUT}.tar.xz --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c .
	fi

	if [ "${TARGET_REMOVE}" == "Y" ]; then
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
		rm -rf "${TARGET_OUTPUT}" || (echo "Cannot remove ${TARGET_OUTPUT}" ; exit 1)
	fi
}

if [ "$(uname -m)" != "x86_64" ]; then
	echo "Not support host architecture (only for x86_64)"
	exit 1
fi

DEBUG=Y

TARGET_DISTRO=
TARGET_ARCH=
TARGET_OUTPUT=
TARGET_TYPE=
TARGET_LOCALE=
TARGET_TIMEZONE=
TARGET_NAME=

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
		-c|--compress) TARGET_COMPRESS="Y" ;;
		-r|--rm) TARGET_REMOVE="Y" ;;
		-i|--include) INCLUDE_PACKAGES="${2}" ; shift 1 ;;
		-e|--exclude) EXCLUDE_PACKAGES="${2}" ; shift 1 ;;
		-n|--name) TARGET_NAME="${2}" ; shift 1 ;;
		-f|--force) FORCE="Y" ; shift 1 ;;
		-h|--help) usage ;;
	   	*) EXTRA_ARGS+=(${1}) ;;
	esac
	shift
done

#set default
if [ "${TARGET_DISTRO}" != "debian" -a "${TARGET_DISTRO}" != "ubuntu" -a "${TARGET_DISTRO}" != "alpine" ]; then
	TARGET_DISTRO=arch
fi
if [ "${TARGET_ARCH}" == "x86_64" ]; then
	TARGET_ARCH=x64
fi
if [ "${TARGET_ARCH}" == "i686" ]; then
	TARGET_ARCH=x86
fi
if [ "${TARGET_ARCH}" == "arm" ]; then
	TARGET_ARCH=armv5
fi
if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "x86" -a "${TARGET_ARCH}" != "armv5" -a "${TARGET_ARCH}" != "armv6h" -a "${TARGET_ARCH}" != "armv7h" -a "${TARGET_ARCH}" != "aarch64" ]; then
	TARGET_ARCH=x64
fi
if [ -z "${TARGET_OUTPUT}" ]; then
	TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}
	TARGET_OUTPUT=$(realpath ${TARGET_OUTPUT})
fi
if [ "${TARGET_TYPE}" != "native" ]; then
	TARGET_TYPE=docker
fi
if [ -z "${TARGET_LOCALE}" ]; then
	TARGET_LOCALE=ko_KR.UTF-8
fi
if [ -z "${TARGET_TIMEZONE}" ]; then
	TARGET_TIMEZONE=Asia/Seoul
fi
if [ "${TARGET_COMPRESS}" != "Y" ]; then
	TARGET_COMPRESS="N"
fi
if [ "${TARGET_REMOVE}" != "Y" ]; then
	TARGET_REMOVE="N"
fi
if [ "${TARGET_TYPE}" == "docker" ]; then
	if [ -z "${TARGET_NAME}" ]; then
		TARGET_NAME=forumi0721/${TARGET_DISTRO}-${TARGET_ARCH}-base
	fi
else
	TARGET_NAME=
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
		usage
	fi
fi

#prepare
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
	rm -rf "${TARGET_OUTPUT}" || (echo "Cannot remove ${TARGET_OUTPUT}" ; exit 1)
fi
mkdir -p "${TARGET_OUTPUT}" || (echo "Cannot create ${TARGET_OUTPUT}" ; exit 1)
chmod 755 ${TARGET_OUTPUT}
if [ "${TARGET_COMPRESS}" == "Y" -a -e "${TARGET_OUTPUT}.tar.xz" ]; then
	rm -rf "${TARGET_OUTPUT}.tar.xz" || (echo "Cannot remove ${TARGET_OUTPUT}.tar.xz" ; exit 1)
fi

#execute
eval make${TARGET_DISTRO}

