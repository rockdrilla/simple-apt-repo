#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause
# (c) 2020, Konstantin Demin

###############################################################################

# repo_root='/var/www/deb'
# name='SimpleAptRepo'
# desc='custom Debian packages for folks'
# web='http://example.com/deb'
# GNUPGHOME='/home/user/.gnupg'
. "$HOME/.config/simplerepo"

###############################################################################

mkdir_p() {
	local ___i
	for ___i ; do
		dirname -z "${___i}" | xargs -0 -r mkdir -p
	done
}

csum_t() { echo -n "$2" | "${1}sum" -b | cut -d ' ' -f 1 ; }
csum_f() { "${1}sum" -b < "$2" | cut -d ' ' -f 1 ; }

###############################################################################

umask 0077

case "$1" in
stage1)
	exec 0<&- 1>&-

	work_root=$2 ; size=$3 ; path=$4

	cd "$work_root/"

	IFS=/ read channel unused_pool distribution component file <<-EOF
	$path
	EOF
	unset unused_pool ## unused variable

	hash=$(csum_t sha1 "$file")


	exec 1>_stage1.mk.d/m.$hash

	a=r/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$channel"

	a=r/$channel/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$distribution"

	a=r/$channel/$distribution/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$component"

	a=i/$channel/$distribution/$component/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$hash"

	case "$file" in
	*.dsc) b=src  ;;
	*.deb) b=bin  ;;
	*)     b=misc ;;
	esac
	a=$a$b
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$hash"


	exec 1>&-


	exec 1>_common.mk.d/m.$hash

	a=h/$channel/$distribution/$component/$hash
	c=$(csum_f sha1 "$repo_root/$path")
	printf '%s :=%s\n' "$a" "$c"

	a=$channel/meta/h/$distribution/$component/$hash
	mkdir_p "$a"
	echo "$c" > "$a"

	k=0
	if [ -s "$repo_root/$a" ] ; then
		if cmp -s "$a" "$repo_root/$a" ; then
			k=1
		fi
	fi

	if [ "$k" = '1' ] ; then
		a=$channel/meta/a/$distribution/$component/$hash
		mkdir_p "$a"
		cat < "$repo_root/$a" > "$a"

		c=$(cat "$a")
		a=a/$channel/$distribution/$component/$hash
		printf '%s :=%s\n' "$a" "$c"

		a=$channel/meta/c/$distribution/$component/$hash
		mkdir_p "$a"
		cat < "$repo_root/$a" > "$a"
	else
		a=$channel/meta/c/$distribution/$component/$hash
		mkdir_p "$a"
		case "$file" in
		*.dsc) $0 dsc "$work_root" $size "$path" > $a ;;
		*.deb) $0 deb "$work_root" $size "$path" > $a ;;
		*)     file "$repo_root/$path" > $a ;;
		esac


		a=a/$channel/$distribution/$component/$hash
		case "$file" in
		*.dsc) c='source' ;;
		*.deb) c=$($0 ctrl-arch "$work_root" $channel $distribution $component $hash) ;;
		*)     c='none' ;;
		esac
		printf '%s :=%s\n' "$a" "$c"

		a=$channel/meta/a/$distribution/$component/$hash
		mkdir_p "$a"
		echo "$c" > "$a"
	fi

	## kinda hack
	a=$channel/meta/a/$distribution/$component/$hash
	c=$(cat "$a")
	case "$c" in
	source) ;;
	none)	;;
	*)
		{
			a=a/$channel/$distribution/$component/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"

			a=a/$channel/$distribution/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"

			a=a/$channel/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"
		} >> _stage1.mk.d/m.$hash
		;;
	esac

	exit 0
	;;
dsc)
	exec 0<&-

	# work_root=$2 ; size=$3 ; path=$4

	cd "$2/"

	p="$repo_root/$4"
	d=$(dirname "$4" | cut -d / -f 2-)
	f=$(basename "$4")

	tmp=$(mktemp -p "$2/_tmp.d")
	if grep -m 1 -Eq '^-----BEGIN PGP' < "$p" ; then
		gpg --batch --quiet < "$p" > "$tmp" 2>/dev/null
	else
		cat < "$p" > "$tmp"
	fi

	## fix #1 - remark pure source control to source package
	sed -e 's/Source:/Package:/' -i "$tmp"

	## fix #2 - add directory info
	# sed -E -e "/^(Checksum|Files)/ i Directory: $d" -i "$tmp"
	n=$(grep -m 1 -nE '^(Checksum|Files)' "$tmp" | cut -d : -f 1)
	sed -E -e "$n i Directory: $d" -i "$tmp"

	## fix #3 - add hashsums of dsc itself
	sha1=$(csum_f sha1 "$p")
	sha256=$(csum_f sha256 "$p")
	md5=$(csum_f md5 "$p")
	sed -E -e "/^Checksums-Sha1:/ a \ $sha1 $3 $f" -i "$tmp"
	sed -E -e "/^Checksums-Sha256:/ a \ $sha256 $3 $f" -i "$tmp"
	sed -E -e "/^Files:/ a \ $md5 $3 $f" -i "$tmp"

	grep -Eve '^$' < "$tmp" ; rm -f "$tmp"
	exit 0
	;;
deb)
	exec 0<&-

	# work_root=$2 ; size=$3 ; path=$4

	cd "$2/"

	p="$repo_root/$4"

	tmp=$(mktemp -p "$2/_tmp.d")
	dpkg-deb -I "$repo_root/$4" control > "$tmp"

	## fix #1 - add file path
	f=$(echo "$4" | cut -d / -f 2-)
	echo "Filename: $f" >> "$tmp"

	## fix #2 - add file size
	echo "Size: $3" >> "$tmp"

	## fix #3 - add hashsums of deb itself
	sha1=$(csum_f sha1 "$p")
	sha256=$(csum_f sha256 "$p")
	md5=$(csum_f md5 "$p")
	echo "MD5sum: $md5" >> "$tmp"
	echo "SHA1: $sha1" >> "$tmp"
	echo "SHA256: $sha256" >> "$tmp"

	grep -Eve '^$' < "$tmp" ; rm -f "$tmp"
	exit 0
	;;
ctrl-arch)
	exec 0<&-

	cd "$2/"
	sed -n -E -e '/^Architecture:\s*(.+)\s*$/{s//\1/;p;}' < "$3/meta/c/$4/$5/$6"

	exit 0
	;;
esac

###############################################################################

## specify either --detach-sign or --clear-sign in params
gnupg_sign() { gpg --sign --armor --output - "$@" ; }

gnupg_warmup() {
	local x y r
	x=$(mktemp)
	y=$(mktemp)
	gnupg_sign     \
	  --batch      \
	  --clear-sign \
	  "$x" > "$y"
	r=$?
	rm "$x" "$y"
	[ $r -eq 0 ] || exit 1
}

gnupg_finish() { gpgconf --kill all; }

###############################################################################

gnupg_warmup

ts_now=$(date '+%s')             ## now
ts_end=$(( ts_now + 86400*180 )) ## now + ~6 months

nproc=$(grep -Ece '^processor' /proc/cpuinfo)
nproc=$(( nproc + (nproc + 1)/2 ))

make() {
	command make               \
	  --no-print-directory     \
	  --no-builtin-rules       \
	  --no-builtin-variables   \
	  --jobs=$nproc            \
	  --directory="$work_root" \
	  --file="$0.mk"           \
	  "$@"
}

work_root=$(mktemp -d)
export work_root

cat > "$work_root/_common.mk" <<-EOF
	repo_root :=$repo_root
	name      :=$name
	desc      :=$desc
	web       :=$web
	ts_now    :=$ts_now
	ts_end    :=$ts_end
EOF

mkdir -p "$work_root/_tmp.d"
mkdir -p "$work_root/_common.mk.d"
mkdir -p "$work_root/_stage1.mk.d"

p='[[:alnum:]][^/]*'
re="^$repo_root/$p/pool/$p/$p/$p/.*\.(dsc|deb)\$"

## stage 1 - scan filesystem for packages and grab meta information
find "$repo_root/" -type f -regextype egrep -regex "$re" -printf '%s %P\n' \
| xargs -r -L 1 -P $nproc "$0" stage1 "$work_root"

## stage 2 - merge some meta information (lists)
make stage2

make update

make deploy

## cleanup

gnupg_finish

rm -rf "$work_root/"

exit 0
