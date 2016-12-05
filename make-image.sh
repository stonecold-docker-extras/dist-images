#!/usr/bin/env bash

if [ "${UID}" -ne 0 ]; then
	sudo "${0}" $*
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

fn_usage() {
	echo "Usage : $(basename "${0}") [-d distro] [-a architecture] [-o output] [-t type] [-l locale] [-z timezone] [-c] [-r] [-i include packages] [-e exclude pacakges]"
	echo "          [-d distro] : arch,alpine,debian,ubuntu (default : arch)"
	echo "          [-a architecture] : x64(x86_64),armv7h,aarch64 (default : x64)"
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

fn_make_alpine() {
	echo "Bootstrap"

	local ALPINE_DIST=edge
	local ALPINE_MIRROR=http://dl-cdn.alpinelinux.org/alpine

	local ALPINE_ARCH=${TARGET_ARCH}
	ALPINE_ARCH=${ALPINE_ARCH/x64/x86_64}
	ALPINE_ARCH=${ALPINE_ARCH/armv7h/armhf}
	ALPINE_ARCH=${ALPINE_ARCH/aarch64/aarch64}

	#qemu
	if [ ! -z "${TARGET_QEMU}" ]; then
		mkdir -p ${TARGET_OUTPUT}/usr/bin
		cp extra/${TARGET_QEMU} ${TARGET_OUTPUT}/usr/bin/
	fi
	local APK_VERSION="$(curl -sSL ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/APKINDEX.tar.gz | tar -Oxz | grep --text '^P:apk-tools-static$' -A1 | tail -n1 | cut -d: -f2)"
	curl -sSL ${ALPINE_MIRROR}/${ALPINE_DIST}/main/${ALPINE_ARCH}/apk-tools-static-${APK_VERSION}.apk | tar -xz -C ${TARGET_OUTPUT} sbin/apk.static  2>/dev/null
	${TARGET_OUTPUT}/sbin/apk.static --repository ${ALPINE_MIRROR}/${ALPINE_DIST}/main --update-cache --allow-untrusted --root ${TARGET_OUTPUT} --initdb add alpine-base 

	echo

	echo "Configuration"

	#mirror
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/main" > ${TARGET_OUTPUT}/etc/apk/repositories
	echo "${ALPINE_MIRROR}/${ALPINE_DIST}/community" >> ${TARGET_OUTPUT}/etc/apk/repositories

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#timezone
	echo "${TARGET_TIMEZONE}" > ${TARGET_OUTPUT}/etc/TZ
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chroot "${TARGET_OUTPUT}" apk update
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" chroot "${TARGET_OUTPUT}" setup-timezone -z Asia/Seoul

	echo


	echo "Clearing"

	rm -rf ${TARGET_OUTPUT}/sbin/apk.static
	rm -rf ${TARGET_OUTPUT}/var/cache/apk/*

	echo

	fn_common
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
	local PACMAN_BASE_PKGS=(bash bzip2 coreutils diffutils filesystem findutils gettext glibc grep gzip less pacman perl procps-ng sed shadow systemd)
	local PACMAN_EXTRA_PKGS=()
	local ARCH_KEYRING=

	local ARCH_ARCH=${TARGET_ARCH}
	ARCH_ARCH=${ARCH_ARCH/x64/x86_64}

	if [ -z "$(ls /var/cache/pacman/pkg | grep "${ARCH_ARCH}.pkg.tar.xz")" ]; then
		rm -rf /var/cache/pacman/pkg/*
	fi

	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "aarch64" ]; then
		#PACMAN_MIRRORLIST='Server = http://mirror.archlinuxarm.org/$arch/$repo'
		PACMAN_MIRRORLIST='Server = http://ca.us.mirror.archlinuxarm.org/$arch/$repo'
		PACMAN_EXTRA_PKGS=('archlinuxarm-keyring' 'haveged')
		ARCH_KEYRING="archlinuxarm"
	else
		PACMAN_MIRRORLIST='Server = http://ftp.kaist.ac.kr/ArchLinux/$repo/os/$arch'
		PACMAN_EXTRA_PKGS=('haveged')
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
	if [ "${TARGET_ARCH}" = "x64" ]; then
	cat << EOF >> "${PACMAN_CONF}"
[multilib]
${PACMAN_MIRRORLIST}
EOF
	fi
	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "aarch64" ]; then
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

	pacstrap -C ${PACMAN_CONF} -c -d -G -M ${TARGET_OUTPUT} ${PACMAN_BASE_PKGS[@]} ${PACMAN_EXTRA_PKGS[@]}

	echo

	echo "Configuration"

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#systemd-sysusers
	arch-chroot ${TARGET_OUTPUT} /usr/bin/systemd-sysusers

	#keyring
	arch-chroot ${TARGET_OUTPUT} /bin/sh -c "haveged ; rm -fr /etc/pacman.d/gnupg ; pacman-key --init ; pacman-key --populate ${ARCH_KEYRING} ; pkill haveged ; pkill gpg-agent ; pacman -Rsn --noconfirm haveged"

	#basic config
	echo "${PACMAN_MIRRORLIST}" > ${TARGET_OUTPUT}/etc/pacman.d/mirrorlist
	sed -i "s/\(Architecture =\) auto/\1 ${ARCH_ARCH}/g" ${TARGET_OUTPUT}/etc/pacman.conf
	sed -i "s/#\(NoUpgrade   =\)/\1 \/etc\/pacman.d\/mirrorlist/g" ${TARGET_OUTPUT}/etc/pacman.conf

	#locale
	sed -i "s/#${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen
	arch-chroot ${TARGET_OUTPUT} locale-gen
	echo "LANG=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/locale.conf
	echo "LC_ALL=${TARGET_LOCALE}" >> ${TARGET_OUTPUT}/etc/locale.conf

	#timezone
	if [ -e "${TARGET_OUTPUT}/usr/share/zoneinfo/${TARGET_TIMEZONE}" ]; then
		ln -sf /usr/share/zoneinfo/${TARGET_TIMEZONE} ${TARGET_OUTPUT}/etc/localtime
	fi

	#skel
	cp -ar ${TARGET_OUTPUT}/etc/skel/. ${TARGET_OUTPUT}/root/

	##yaourt
	#if [ -e extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz -a -e extra/yaourt-*-any.pkg.tar.xz ]; then
	#	cp extra/package-query-*-${ARCH_ARCH}.pkg.tar.xz ${TARGET_OUTPUT}/
	#	cp extra/yaourt-*-any.pkg.tar.xz ${TARGET_OUTPUT}/
	#	arch-chroot ${TARGET_OUTPUT} /bin/sh -c "pacman -U --noconfirm --asdeps /package-query-*; pacman -U --noconfirm /yaourt-*-any.pkg.tar.xz"
	#	rm -rf ${TARGET_OUTPUT}/*.pkg.tar.xz
	#fi

	echo

	echo "Clearing"

	rm -rf "${PACMAN_CONF}"

	rm -rf ${TARGET_OUTPUT}/var/cache/pacman/pkg/*
	rm -rf ${TARGET_OUTPUT}/var/lib/pacman/sync/*
	rm -rf ${TARGET_OUTPUT}/tmp/yaourt*

	echo

	fn_common
}

fn_make_debian() {
	local DEBIAN_DIST=jessie
	local DEBIAN_MIRROR=http://ftp.kr.debian.org/debian
	local DEBIAN_EXTRA=locales

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	fn_make_debian_common "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

fn_make_ubuntu() {
	local DEBIAN_DIST=xenial
	local DEBIAN_MIRROR=
	if [ "${TARGET_ARCH}" = "armv7h" -o "${TARGET_ARCH}" = "aarch64" ]; then
		DEBIAN_MIRROR=http://ports.ubuntu.com/ubuntu-ports
	else
		DEBIAN_MIRROR=http://kr.archive.ubuntu.com/ubuntu
	fi
	local DEBIAN_EXTRA=

	local DEBIAN_ARCH=${TARGET_ARCH}
	DEBIAN_ARCH=${DEBIAN_ARCH/x64/amd64}
	DEBIAN_ARCH=${DEBIAN_ARCH/armv7h/armhf}
	DEBIAN_ARCH=${DEBIAN_ARCH/aarch64/arm64}

	fn_make_debian_common "${DEBIAN_DIST}" "${DEBIAN_MIRROR}" "${DEBIAN_EXTRA}" "${DEBIAN_ARCH}"
}

fn_make_debian_common() {
	if ! debootstrap --help &>/dev/null ; then
		echo "Could not find debootstrap. Run pacman -S debootstrap"
		exit 1
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
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true debootstrap --foreign ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} ${TARGET_OUTPUT} ${DEBIAN_MIRROR}

		echo "debootstrap 2nd"
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /debootstrap/debootstrap --second-stage

		echo "debootstrap 3rd"
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" dpkg --configure -a
	else
		echo "debootstrap"
		PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive debootstrap ${DEBIAN_OPTION[@]} ${DEBIAN_DIST} ${TARGET_OUTPUT} ${DEBIAN_MIRROR}
	fi

	#resolve
	cat << EOF > ${TARGET_OUTPUT}/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

	#locale
	sed -i "s/# ${TARGET_LOCALE}/${TARGET_LOCALE}/g" ${TARGET_OUTPUT}/etc/locale.gen
	PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LANG=C LC_ALL=C chroot "${TARGET_OUTPUT}" locale-gen
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
		cat << EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main contrib non-free
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main contrib non-free

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main contrib non-free
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main contrib non-free

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed-updates main contrib non-free
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed-updates main contrib non-free

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main contrib non-free
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main contrib non-free

deb http://security.debian.org ${DEBIAN_DIST}/updates main contrib non-free
# deb-src http://security.debian.org ${DEBIAN_DIST}/updates main contrib non-free
EOF
	fi
	if [ "${TARGET_DISTRO}" = "ubuntu" ]; then
		#sed -i "s/ ${DEBIAN_DIST} main$/ ${DEBIAN_DIST} main universe/; p; s/ ${DEBIAN_DIST} main/ ${DEBIAN_DIST}-updates main/; p; s/ ${DEBIAN_DIST}-updates main/ ${DEBIAN_DIST}-security main/" ${TARGET_OUTPUT}/etc/apt/sources.list
		cat << EOF > ${TARGET_OUTPUT}/etc/apt/sources.list
deb ${DEBIAN_MIRROR} ${DEBIAN_DIST} main universe restricted multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST} main universe restricted multiverse

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main universe restricted multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-updates main universe restricted multiverse

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed main universe restricted multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-proposed main universe restricted multiverse

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main universe restricted multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-backports main universe restricted multiverse

deb ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main universe restricted multiverse
# deb-src ${DEBIAN_MIRROR} ${DEBIAN_DIST}-security main universe restricted multiverse
EOF
	fi

	#PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" LC_ALL=C DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true chroot "${TARGET_OUTPUT}" /bin/sh -c "apt-get -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true update ; apt-get -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true dist-upgrade -y ; apt-get -o Acquire::Languages=none -o Acquire::GzipIndexes=true -o Acquire::CompressionTypes::Order::=gz -o APT::Install-Recommends=0 -o APT::Install-Suggests=0 -o APT::Get::Assume-Yes=true -o APT::Get::allow-downgrades=true -o APT::Get::allow-remove-essential=true -o APT::Get::allow-change-held-packages=true install apt-utils -y ; apt-get autoremove --purge -y ; apt-get autoclean -y ; apt-get clean ; find /var/lib/apt -type f -exec rm \"{}\" \\;"
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

	fn_common
}

fn_common() {
	if [ "${TARGET_TYPE}" = "docker" ]; then
		# udev doesn't work in containers, rebuild /dev
		local TARGET_DEV=${TARGET_OUTPUT}/dev
		rm -rf ${TARGET_OUTPUT}/dev
		mkdir -p ${TARGET_OUTPUT}/dev
		mknod -m 666 ${TARGET_OUTPUT}/dev/null c 1 3
		mknod -m 666 ${TARGET_OUTPUT}/dev/zero c 1 5
		mknod -m 666 ${TARGET_OUTPUT}/dev/random c 1 8
		mknod -m 666 ${TARGET_OUTPUT}/dev/urandom c 1 9
		mkdir -m 755 ${TARGET_OUTPUT}/dev/pts
		mkdir -m 1777 ${TARGET_OUTPUT}/dev/shm
		mknod -m 666 ${TARGET_OUTPUT}/dev/tty c 5 0
		mknod -m 600 ${TARGET_OUTPUT}/dev/console c 5 1
		mknod -m 666 ${TARGET_OUTPUT}/dev/tty0 c 4 0
		mknod -m 666 ${TARGET_OUTPUT}/dev/full c 1 7
		mknod -m 600 ${TARGET_OUTPUT}/dev/initctl p
		mknod -m 666 ${TARGET_OUTPUT}/dev/ptmx c 5 2
		ln -sf /proc/self/fd ${TARGET_OUTPUT}/dev/fd

		echo "Docker Import"

		./update-image.sh -d ${TARGET_DISTRO} -a ${TARGET_ARCH} -i -f -q

		echo
	fi

	if [ "${TARGET_COMPRESS}" = "Y" ]; then
		tar -Jcf ${TARGET_OUTPUT}.tar.xz --numeric-owner --xattrs --acls -C ${TARGET_OUTPUT} -c .
	fi

	if [ "${TARGET_REMOVE}" = "Y" ]; then
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
if [ "${TARGET_ARCH}" != "x64" -a "${TARGET_ARCH}" != "armv7h" -a "${TARGET_ARCH}" != "aarch64" ]; then
	fn_usage
fi
if [ -z "${TARGET_OUTPUT}" ]; then
	TARGET_OUTPUT=dist-${TARGET_DISTRO}-${TARGET_ARCH}
	TARGET_OUTPUT=$(realpath ${TARGET_OUTPUT})
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
if [ "${TARGET_COMPRESS}" != "Y" ]; then
	TARGET_COMPRESS="N"
fi
if [ "${TARGET_REMOVE}" != "Y" ]; then
	TARGET_REMOVE="N"
fi
if [ "${TARGET_TYPE}" = "docker" ]; then
	if [ -z "${TARGET_NAME}" ]; then
		TARGET_NAME=forumi0721${TARGET_DISTRO}${TARGET_ARCH}/${TARGET_DISTRO}-${TARGET_ARCH}-base
	fi
else
	TARGET_NAME=
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
if [ "${TARGET_COMPRESS}" = "Y" -a -e "${TARGET_OUTPUT}.tar.xz" ]; then
	rm -rf "${TARGET_OUTPUT}.tar.xz" || (echo "Cannot remove ${TARGET_OUTPUT}.tar.xz" ; exit 1)
fi

#execute
eval fn_make_${TARGET_DISTRO}

