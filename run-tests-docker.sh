#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
	./run-tests-docker.sh [options] [TEST_PATTERN]

Options:
	-t, --tag <name>     Docker image tag (default: bash-utils)
	--no-build           Skip docker build; only run
	--no-tty             Disable TTY allocation (-t)
	-v, --verbose        Enable verbose test output
	-q, --quiet          Suppress output except for failures
	-c, --coverage       Run with coverage reporting (if available)
	--test TEST          Run specific test file or pattern
	-l, --list           List available test files
	-h, --help           Show this help

EXAMPLES:
	./run-tests-docker.sh
	./run-tests-docker.sh -v
	./run-tests-docker.sh --test system-mount
	./run-tests-docker.sh tests/test_system-mount.bats
	./run-tests-docker.sh --list

Notes:
	- Runs the image entrypoint (see Dockerfile).
	- Additional test options and patterns are passed to run-tests.sh in the container.
EOF
}

main() {
	local tag="bash-utils"
	local do_build=1
	local use_tty=1
	local test_args=()

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
			-v|--verbose)
				test_args+=("--verbose")
				shift
				;;
			-q|--quiet)
				test_args+=("--quiet")
				shift
				;;
			-c|--coverage)
				test_args+=("--coverage")
				shift
				;;
			--test)
				[[ ${2-} ]] || { echo "[ERROR] Missing value for $1" >&2; exit 2; }
				test_args+=("--test" "$2")
				shift 2
				;;
			-l|--list)
				test_args+=("--list")
				shift
				;;
			-h|--help)
				usage
				exit 0
				;;
			-*)
				echo "[ERROR] Unknown option: $1" >&2
				usage >&2
				exit 2
				;;
			*)
				test_args+=("$1")
				shift
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
		docker run -ti --rm "$tag" "${test_args[@]}"
	else
		docker run -i --rm "$tag" "${test_args[@]}"
	fi
}

main "$@"