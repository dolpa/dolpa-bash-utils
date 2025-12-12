#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
	./run-tests-docker.sh [options]

Options:
	-t, --tag <name>     Docker image tag (default: bash-utils)
	--no-build           Skip docker build; only run
	--no-tty             Disable TTY allocation (-t)
	-h, --help           Show this help

Notes:
	- Runs the image entrypoint (see Dockerfile). The container exit code is
		returned as this script's exit code.
EOF
}

main() {
	local tag="bash-utils"
	local do_build=1
	local use_tty=1

	while (($#)); do
		case "$1" in
			-t|--tag)
				[[ ${2-} ]] || { echo "[ERROR] Missing value for $1" >&2; exit 2; }
				tag="$2"
				shift 2
				;;
			--no-build)
				do_build=0
				shift
				;;
			--no-tty)
				use_tty=0
				shift
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				echo "[ERROR] Unknown option: $1" >&2
				usage >&2
				exit 2
				;;
		esac
	done

	command -v docker >/dev/null 2>&1 || { echo "[ERROR] docker not found" >&2; exit 127; }
	[[ -f Dockerfile ]] || { echo "[ERROR] Dockerfile not found in $PWD" >&2; exit 2; }

	if (( do_build )); then
		docker build -t "$tag" .
	fi

	# Propagate the container's exit code.
	if (( use_tty )) && [[ -t 0 ]]; then
		docker run -ti --rm "$tag"
	else
		docker run -i --rm "$tag"
	fi
}

main "$@"