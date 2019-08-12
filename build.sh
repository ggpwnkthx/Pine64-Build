#!/bin/bash
tag=$1
if [ -z "$tag" ]; then
	tag="untitled"
fi
compression_level=9
images=images
mounts=$images/mounted

# Set up required directories
if [ ! -d $images ]; then
	mkdir -p $images
fi
if [ ! -d $mounts ]; then
	mkdir -p $mounts
fi

current_mount=""

FROM() {
	distro=$1
	build=$2
	dev=$3
	version=$4
	arch=$5
	if [ -z "$version" ]; then
	version=$(ls $images/ | grep $distro-$build-$dev | grep $arch.img.xz | sed "s/$distro-$build-$dev-//g" | sed "s/-$arch.img.xz//g")
	fi
	if [ -z "$version" ] || [ "$version" == "latest" ]; then
		echo "Checking for the latest version of ayufan's builds..."
		url=$(curl -s https://api.github.com/repos/ayufan-rock64/linux-build/releases/latest | grep $distro-$build-$dev | grep $arch | grep browser_download_url |  awk '{print $2}' | awk -F\" '{print $2}')
		version=$(echo "${url##*/}" | sed "s/$distro-$build-$dev-//g" | sed "s/-$arch.img.xz//g")
	else
		echo "Using local version: $version"
	fi
	## Download
	if [ ! -f $images/$distro-$build-$dev-$version-$arch.img.xz ]; then
		echo "Downloading ayufan's $version build..."
		wget $url -O $images/$distro-$build-$dev-$version-$arch.img.xz -q --show-progress
	fi
	## Clean Old
	if [ -f $tag.img ]; then
		rm $tag.img
	fi
	if [ -f $tag.img.xz ]; then
		rm $tag.img.xz
	fi
	## Unpack
	if [ ! -f $images/$distro-$build-$dev-$version-$arch.img ]; then
		echo "Decompressing image..."
		xz -dvk $images/$distro-$build-$dev-$version-$arch.img.xz
		mv $images/$distro-$build-$dev-$version-$arch.img $images/$tag.img
	fi
	## Loopback 
	if [ -f $images/$tag.img ]; then
		losetup -Pf $images/$tag.img

		## Mount
		current_mount=$mounts/$tag
		if [ ! -d $current_mount ]; then
			mkdir -p $current_mount
		fi
		mount /dev/loop0p7 $current_mount
		mount /dev/loop0p6 $current_mount/boot/efi
	fi
}
COPY() {
	cp -r $1 $current_mount$2
}
declare -A environmenal_variables
ENV() {
	environmenal_variables[$1]=$2
}
RUN() {
	# Start script
	start="mount -t proc proc proc/"
	for K in "${!environmenal_variables[@]}"; do 
		start="$start; export $K=${environmenal_variables[$K]}"
	done
	
	# Run script
	run="$@"
	run=$(echo "$run" | sed 's/\\\&/\&/g')
	run=$(echo "$run" | sed 's/\\;/;/g')
	run=$(echo "$run" | sed 's/\\|/|/g')
	run=$(echo "$run" | sed 's/\\</</g')
	run=$(echo "$run" | sed 's/\\>/>/g')
	chmod +x $current_mount/run
	
	# Finish script
	stop="umount /proc"
	
	# chroot
	echo
	echo "chroot session"
	echo "----------------------------------------------------"
	cat << EOF | chroot $current_mount
$start
$run
$stop
EOF
	echo "----------------------------------------------------"
}
PARSE() {
	cat $1 | \
	sed 's/\&/\\\&/g' | \
	sed 's/;/\\;/g' | \
	sed 's/|/\\|/g' | \
	sed 's/"/\\"/g' | \
	sed 's/</\\</g' | \
	sed 's/>/\\>/g'
}

if [ -z "$2" ]; then
	buildfile=buildfile
else
	buildfile=$2
fi

source <(PARSE $buildfile)

RUN dd if=/dev/zero of=zero.txt bs=30M
RUN dd if=/dev/zero of=/boot/efi/zero.txt bs=30M
RUN rm -f zero.txt /boot/efi/zero.txt

## Unmount
umount /dev/loop0p6
umount /dev/loop0p7
losetup -d /dev/loop0
xz -$compression_level -v $images/$tag.img
