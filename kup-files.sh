#!/usr/bin/env bash

usage() {
	local old_xtrace
	old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	echo "${script_name} (korg-utils) - Recursively kup files." >&2
	echo "Usage: ${script_name} [flags] top-dir" >&2
	echo "Option flags:" >&2
	echo "  -r --kup-path - kup remote path. Default: '${kup_path}'." >&2
	echo "  -d --dry-run  - Do not upload." >&2
	echo "  -b --batch    - Output a kup batchfile. Default: '${batch_file}'." >&2
	echo "  -h --help     - Show this help and exit." >&2
	echo "  -v --verbose  - Verbose execution." >&2
	echo "  -g --debug    - Extra verbose execution." >&2
	echo "Send bug reports to: Geoff Levand <geoff@infradead.org>." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="r:db::hvg"
	local long_opts="kup-path:,dry-run,batch::,help,verbose,debug"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${script_name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-r | --kup-path)
			kup_path="${2}"
			shift 2
			;;
		-d | --dry-run)
			dry_run=1
			shift
			;;
		-b | --batch)
			batch=1
			if [[ ${2} ]]; then
				batch_file="${2}"
			fi
			shift 2
			;;
		-h | --help)
			usage=1
			shift
			;;
		-v | --verbose)
			verbose=1
			shift
			;;
		-g | --debug)
			verbose=1
			debug=1
			set -x
			shift
			;;
		--)
			shift
			if [[ ${1} ]]; then
				top_dir="${1}"
				shift
			fi
			if [[ ${*} ]]; then
				set +o xtrace
				echo "${script_name}: ERROR: Got extra args: '${*}'" >&2
				usage
				exit 1
			fi
			break
			;;
		*)
			echo "${script_name}: ERROR: Internal opts: '${*}'" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}
	local sec=${SECONDS}

	if [[ ! ${debug} && -d "${tmp_dir}" ]]; then
		# FIXME: need to keep for batch???
		rm -rf "${tmp_dir:?}"
	fi

	set +x
	echo "${script_name}: Done: ${result}, ${sec} sec." >&2
}

check_directory() {
	local src="${1}"
	local msg="${2}"
	local usage="${3}"

	if [[ ! -d "${src}" ]]; then
		echo "${script_name}: ERROR (${FUNCNAME[0]}): Directory not found${msg}: '${src}'" >&2
		[[ -z "${usage}" ]] || usage
		exit 1
	fi
}

check_files() {
	local f_array=("${@}")

	for f in "${f_array[@]}"; do
		local ext1="${f##*.}"
		local gz_base="${f%.gz}"
		local ext2="${gz_base##*.}"

		if [[ ${verbose} ]]; then
			echo "${script_name}: INFO: Checking '${f}'" >&2
		fi

		if [[ "${ext1}" == 'sign' ]]; then
			echo "${script_name}: ERROR: Found sign file: '${f}'" >&2
			exit 1
		fi

		if [[ "${ext1}" == 'sig' ]]; then
			echo "${script_name}: ERROR: Found sig file: '${f}'" >&2
			exit 1
		fi

		if [[ "${ext1}" == 'gz' ]]; then

			if [[ "${ext2}" != 'tar' ]]; then
				echo "${script_name}: ERROR: Unsupported archive: '${f}'" >&2
				exit 1
			fi
		fi
	done
}

#===============================================================================
export PS4='\[\e[0;33m\]+ ${BASH_SOURCE##*/}:${LINENO}:(${FUNCNAME[0]:-"?"}):\[\e[0m\] '
script_name="${0##*/}"

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
SECONDS=0

trap "on_exit 'failed'" EXIT
set -e
set -o pipefail

start_time="$(date +%Y.%m.%d-%H.%M.%S)"

process_opts "${@}"

if [[ ${batch} ]]; then
	batch_file="${batch_file:-/tmp/kup-batchfile-${start_time}}"
	batch_file="$(realpath --canonicalize-missing "${batch_file}")"
fi

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if [[ ! ${kup_path} ]]; then
	echo "${script_name}: ERROR: Must provide --kup-path option." >&2
	usage
	exit 1
fi

if [[ "${kup_path:(-1)}" != '/' ]]; then
	kup_path="${kup_path}/"
fi

check_directory "${top_dir}" ' top-dir' 1
top_dir="$(realpath -e "${top_dir}")"

readarray -t file_array < <(find "${top_dir}" -type f | sort)

echo "${script_name}: INFO: Processing ${#file_array[@]} files." >&2
if [[ ${verbose} ]]; then
	echo ''
fi

tmp_dir="$(mktemp --tmpdir --directory "${script_name%.*}.XXXX")"

check_files "${file_array[@]}"

if [[ ${batch} && -e "${batch_file}" ]]; then
	rm "${batch_file:?}"
fi

for f in "${file_array[@]}"; do
	rel_file="${f#${top_dir}/}"
	rel_path="${rel_file%/*}/"
	ext1="${f##*.}"
	gz_base="${f%.gz}"
	ext2="${gz_base##*.}"

	if [[ "${ext1}" == 'gz' ]]; then
		src="${tmp_dir}/${rel_file%.gz}"
		sig="${src}.sign"
		mkdir -p "${sig%/*}"

		if [[ ${verbose} ]]; then
			echo "INFO: gunzip '${f}' > '${src}'" >&2
		fi
		gunzip --keep --stdout "${f}" > "${src}"
	else
		src="${f}"
		sig="${tmp_dir}/${rel_file}.sign"
		mkdir -p "${sig%/*}"
	fi

	if [[ ${verbose} ]]; then
		echo "INFO: sign   '${src}' > '${sig}'" >&2
	else
		gpg_extra="--quiet"
	fi
	gpg ${gpg_extra} --detach-sign --output "${sig}" "${src}"

	if [[ ${verbose} ]]; then
		echo "INFO: kup    '${f}' '${sig}' => '${kup_path}${rel_path}'" >&2
	fi

	if [[ ${batch} ]]; then
		kup --batch put "${f}" "${sig}" "${kup_path}${rel_path}" >> "${batch_file}"
	else
		if [[ ! ${dry_run} ]]; then
			kup put "${f}" "${sig}" "${kup_path}${rel_path}"
		fi
	fi

	if [[ ${verbose} ]]; then
		echo ''
	fi
done

if [[ ${batch} ]]; then
	echo "${script_name}: INFO: kup batchfile in '${batch_file}'." >&2
fi

trap "on_exit 'Success'" EXIT
exit 0
