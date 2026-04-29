#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
	./run-tests-docker.sh [options] [test_files...]

Options:
	-t, --tag <name>     Docker image tag (default: bash-utils)
	--no-build           Skip docker build; only run
	--no-tty             Disable TTY allocation (-t)
	-v, --verbose        Enable verbose test output
	-q, --quiet          Suppress output except for failures
	-l, --list           List available test files
	-h, --help           Show this help

Test File Arguments:
	test_files           Specific test files to run (e.g., test_ansi.bats)
	                     If no files specified, runs all tests

Examples:
	./run-tests-docker.sh                    # Run all tests
	./run-tests-docker.sh test_ansi.bats     # Run only ANSI tests
	./run-tests-docker.sh -v test_config.bats test_args.bats  # Run specific tests with verbose output

Notes:
	- Runs the image entrypoint (see Dockerfile). The container exit code is
		returned as this script's exit code.
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
				# Treat remaining arguments as test files
				test_args+=("$@")
				break
				;;
		esac
	done

	command -v docker >/dev/null 2>&1 || { echo "[ERROR] docker not found" >&2; exit 127; }
	[[ -f Dockerfile ]] || { echo "[ERROR] Dockerfile not found in $PWD" >&2; exit 2; }

	if (( do_build )); then
		docker build -t "$tag" .
	fi

	# Prepare the docker run command with volume mount to pass test files
	local docker_cmd=("docker" "run")
	
	# Mount the current directory over the baked-in copy so code changes are
	# always reflected without needing a Docker rebuild.
	if (( use_tty )) && [[ -t 0 ]]; then
		docker_cmd+=("-ti")
	else
		docker_cmd+=("-i")
	fi
	
	docker_cmd+=("--rm" "-v" "${PWD}:/opt/bash-utils" "$tag")
	
	# Add test arguments if any were provided
	if (( ${#test_args[@]} > 0 )); then
		docker_cmd+=("${test_args[@]}")
	fi

	# Propagate the container's exit code.
	"${docker_cmd[@]}"
}

main "$@"