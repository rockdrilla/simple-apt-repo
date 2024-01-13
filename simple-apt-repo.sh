#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# (c) 2020-2024, Konstantin Demin

set -ef

###############################################################################

# repo_root='/var/www/deb'
# name='SimpleAptRepo'
# desc='custom Debian packages for folks'
# web='http://deb.example.com'
# comp_list='gz xz bz2 zst'
# GNUPGHOME="${HOME}/.gnupg"
. "${HOME:?}/.config/simple-apt-repo"
: "${repo_root:?}" "${name:?}" "${desc:?}" "${web:?}"
[ -d "${repo_root}" ] || ls -ld "${repo_root}"
: "${comp_list:=gz xz}"
: "${GNUPGHOME:=${HOME}/.gnupg}"
export GNUPGHOME

###############################################################################

mkdir_for() {
	for ___i ; do
		dirname -z "${___i}"
	done \
	| grep -zEv '^$' | sort -zuV | xargs -0 -r mkdir -p
	unset ___i
}

csum_t() { printf '%s' "$2" | "${1}sum" -b | cut -d ' ' -f 1 ; }
csum_f() { "${1}sum" -b < "$2" | cut -d ' ' -f 1 ; }

###############################################################################

umask 0077

case "$1" in
stage1 )
	exec 0<&- 1>&-

	WORK_ROOT=$2 ; size=$3 ; path=$4

	cd "${WORK_ROOT}/"

	IFS=/ read -r channel _unused_pool distribution component file <<-EOF
	${path}
	EOF
	unset _unused_pool

	hash=$(csum_t sha1 "${file}")

	exec > "_stage1.mk.d/m.${hash}"

	a=r/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "${channel}"

	a=r/${channel}/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "${distribution}"

	a=r/${channel}/${distribution}/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "${component}"

	a=i/${channel}/${distribution}/${component}/_
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "${hash}"

	case "${file}" in
	*.deb | *.udeb ) b=bin ;;
	*.dsc ) b=src ;;
	* )     b=misc ;;
	esac
	a="$a$b"
	printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "${hash}"

	exec 1>&-

	exec > "_common.mk.d/m.${hash}"

	a=h/${channel}/${distribution}/${component}/${hash}
	c=$(csum_f sha1 "${repo_root}/${path}")
	printf '%s :=%s\n' "$a" "$c"

	a=${channel}/.meta/h/${distribution}/${component}/${hash}
	mkdir_for "$a"
	echo "$c" > "$a"

	k=0
	while [ -s "${repo_root}/$a" ] ; do
		cmp -s "$a" "${repo_root}/$a" || break
		k=1 ; break
	done

	if [ "$k" = 1 ] ; then
		a=${channel}/.meta/c/${distribution}/${component}/${hash}
		mkdir_for "$a"
		cat < "${repo_root}/$a" > "$a"

		a=${channel}/.meta/a/${distribution}/${component}/${hash}
		mkdir_for "$a"
		cat < "${repo_root}/$a" > "$a"
		c=$(cat "$a")

		a=a/${channel}/${distribution}/${component}/${hash}
		printf '%s :=%s\n' "$a" "$c"
	else
		a=${channel}/.meta/c/${distribution}/${component}/${hash}
		mkdir_for "$a"
		case "${file}" in
		*.deb | *.udeb )
			"$0" deb "${WORK_ROOT}" "${size}" "${path}" > "$a"
			c=$("$0" ctrl-arch "${WORK_ROOT}" "${channel}" "${distribution}" "${component}" "${hash}")
		;;
		*.dsc )
			c='source'
			"$0" dsc "${WORK_ROOT}" "${size}" "${path}" > "$a"
		;;
		* )
			c='none'
			file "${repo_root}/${path}" > "$a"
		;;
		esac

		a=a/${channel}/${distribution}/${component}/${hash}
		printf '%s :=%s\n' "$a" "$c"

		a=${channel}/.meta/a/${distribution}/${component}/${hash}
		mkdir_for "$a"
		echo "$c" > "$a"
	fi

	## kinda hack
	a=${channel}/.meta/a/${distribution}/${component}/${hash}
	c=$(cat "$a")
	case "$c" in
	source | none ) ;;
	* )
		{
			a=a/${channel}/${distribution}/${component}/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"

			a=a/${channel}/${distribution}/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"

			a=a/${channel}/_
			printf '%s :=$(sort $(%s) %s)\n' "$a" "$a" "$c"
		} >> "_stage1.mk.d/m.${hash}"
	;;
	esac

	exit 0
;;
dsc )
	exec 0<&-

	# WORK_ROOT=$2 ; size=$3 ; path=$4

	cd "$2/"

	p="${repo_root}/$4"
	d=$(dirname "$4" | cut -d / -f 2-)
	f=$(basename "$4")

	tmp=$(mktemp -p "$2/_tmp.d")
	if grep -m 1 -Eq '^-----BEGIN PGP' < "$p" ; then
		gpg --batch --quiet < "$p" > "${tmp}" 2>/dev/null || :
	else
		cat < "$p" > "${tmp}"
	fi

	## fix #1 - remark pure source control to source package
	sed -e 's/Source:/Package:/' -i "${tmp}"

	## fix #2 - add directory info
	# sed -E -e "/^(Checksum|Files)/ i Directory: $d" -i "${tmp}"
	n=$(grep -m 1 -nE '^(Checksum|Files)' "${tmp}" | cut -d : -f 1)
	sed -E -e "$n i Directory: $d" -i "${tmp}"

	## fix #3 - add hashsums of dsc itself
	sha1=$(csum_f sha1 "$p")
	sha256=$(csum_f sha256 "$p")
	md5=$(csum_f md5 "$p")
	sed -E -e "/^Checksums-Sha1:/ a \ ${sha1} $3 $f" -i "${tmp}"
	sed -E -e "/^Checksums-Sha256:/ a \ ${sha256} $3 $f" -i "${tmp}"
	sed -E -e "/^Files:/ a \ ${md5} $3 $f" -i "${tmp}"

	grep -Eve '^$' < "${tmp}" ; rm -f "${tmp}"
	exit 0
;;
deb )
	exec 0<&-

	# WORK_ROOT=$2 ; size=$3 ; path=$4

	cd "$2/"

	p="${repo_root}/$4"

	tmp=$(mktemp -p "$2/_tmp.d")
	dpkg-deb -I "${repo_root}/$4" control > "${tmp}"

	## fix #1 - add file path
	f=$(echo "$4" | cut -d / -f 2-)
	echo "Filename: $f" >> "${tmp}"

	## fix #2 - add file size
	echo "Size: $3" >> "${tmp}"

	## fix #3 - add hashsums of deb itself
	sha1=$(csum_f sha1 "$p")
	sha256=$(csum_f sha256 "$p")
	md5=$(csum_f md5 "$p")
	echo "MD5sum: ${md5}" >> "${tmp}"
	echo "SHA1: ${sha1}" >> "${tmp}"
	echo "SHA256: ${sha256}" >> "${tmp}"

	grep -Ev '^$' < "${tmp}" ; rm -f "${tmp}"
	exit 0
;;
ctrl-arch )
	exec 0<&-

	# WORK_ROOT=$2 ; channel=$3 ; distribution=$4 ; component=$5 ; hash=$6

	cd "$2/"
	sed -nE '/^Architecture:\s*(.+)\s*$/{s//\1/;p;}' < "$3/.meta/c/$4/$5/$6"

	exit 0
;;
esac

###############################################################################

## specify either --detach-sign or --clear-sign in params
gnupg_sign() { gpg --sign --armor --output - "$@" ; }

gnupg_warmup() {
	___x=$(mktemp) ; : "${___x:?}"
	___y=$(mktemp) ; : "${___y:?}"
	set +e
	echo > "${___x}"
	gnupg_sign     \
	  --batch      \
	  --clear-sign \
	  "${___x}" > "${___y}"
	___r=$?
	set -e
	rm -f "${___x}" "${___y}" ; unset ___x ___y
	[ ${___r} = 0 ] || exit ${___r}
	unset ___r
}

gnupg_finish() { gpgconf --kill all; }

###############################################################################

gnupg_warmup

ts_now=$(date '+%s')
## now + ~6 months
ts_end=$(( ts_now + 86400*180 ))

## intrusive parallelism
nproc=$(nproc)
nproc=$(( (nproc*4 + 3)/2 ))
[ ${nproc} -le 20 ] || nproc=20

do_make() {
	make \
	  --no-print-directory \
	  --no-builtin-rules \
	  --no-builtin-variables \
	  --jobs=${nproc} \
	  --directory="${WORK_ROOT}" \
	  --file="$0.mk" \
	  "$@"
}

WORK_ROOT=$(mktemp -d) ; : "${WORK_ROOT:?}"
export WORK_ROOT

cat > "${WORK_ROOT}/_common.mk" <<-EOF
	repo_root :=${repo_root}
	name      :=${name}
	desc      :=${desc}
	web       :=${web}
	comp_list :=${comp_list}
	ts_now    :=${ts_now}
	ts_end    :=${ts_end}
EOF

mkdir -p \
  "${WORK_ROOT}/_tmp.d" \
  "${WORK_ROOT}/_common.mk.d" \
  "${WORK_ROOT}/_stage1.mk.d" \


p='[[:alnum:]]([^/]*[[:alnum:]])?'

set +e

## stage 1 - scan filesystem for packages and grab meta information
find "${repo_root}/" -follow -type f -printf '%s %P\0' \
| grep -zEv '^0 ' \
| grep -zE "^[0-9]+ $p/pool/$p/$p/$p/.*\\.(deb|dsc|udeb)\$" \
| sed -zE 's/^([0-9]+) (.+)$/\1\o000\2/' \
| xargs -0 -r -n 2 -P ${nproc} "$0" stage1 "${WORK_ROOT}"

set -e

## stage 2 - merge some meta information (lists)
do_make stage2

do_make update

do_make deploy

## cleanup

gnupg_finish

rm -rf "${WORK_ROOT}"

exit 0
