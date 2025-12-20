#!/usr/bin/env bats

setup() {
  export NO_COLOR=1
}

define_bash() {
  # The sysctl installer requires Bash 4+. On macOS, /bin/bash is typically 3.2.
  if [[ -n "${BASH_BIN:-}" ]]; then
    return 0
  fi

  local candidates=()
  [[ -x /opt/homebrew/bin/bash ]] && candidates+=("/opt/homebrew/bin/bash")
  [[ -x /usr/local/bin/bash ]] && candidates+=("/usr/local/bin/bash")
  candidates+=("$(command -v bash)")

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -x "$candidate" ]] || continue
    if "$candidate" -c '[[ ${BASH_VERSINFO[0]} -ge 4 ]]' >/dev/null 2>&1; then
      BASH_BIN="$candidate"
      export BASH_BIN
      return 0
    fi
  done

  skip "Bash 4+ is required to run install.sh. Install with: brew install bash (or set BASH_BIN=/path/to/bash)"
}

define_root() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"

  # This is an integration test for the sysctl installer. Depending on how this
  # repo is checked out, `install.sh` may live:
  # - at the monorepo root (e.g. when running from dolpa-sysctl/lib), or
  # - in a sibling repo (dolpa-sysctl) next to this repo.
  if [[ -f "${ROOT_DIR}/install.sh" ]]; then
    INSTALL_SH="${ROOT_DIR}/install.sh"
    return 0
  fi
  if [[ -f "${ROOT_DIR}/dolpa-sysctl/install.sh" ]]; then
    INSTALL_SH="${ROOT_DIR}/dolpa-sysctl/install.sh"
    return 0
  fi

  skip "install.sh not found at ${ROOT_DIR}/install.sh or ${ROOT_DIR}/dolpa-sysctl/install.sh"
}

@test "install.sh list includes ai-x88-srv profile (supports performanc typo)" {
  define_root
  define_bash
  run "${BASH_BIN}" "${INSTALL_SH}" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ai-x88-srv"* ]]
}

@test "dry-run install does not require root" {
  define_root
  define_bash
  run "${BASH_BIN}" "${INSTALL_SH}" --dry-run install dell-xps
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY RUN]"* ]]
}

@test "auto-detect can be overridden via SYSCTL_SYSTEM_NAME" {
  define_root
  define_bash
  SYSCTL_SYSTEM_NAME=ai-x88-srv run "${BASH_BIN}" "${INSTALL_SH}" --dry-run --auto-detect install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing sysctl settings for system: ai-x88-srv"* ]]
  # Source file may be the legacy typo, but destination should be normalized.
  [[ "$output" == *"99-ai-x88-srv-performanc.conf"* || "$output" == *"99-ai-x88-srv-performance.conf"* ]]
  [[ "$output" == *"/etc/sysctl.d/99-ai-x88-srv-performance.conf"* ]]
}

@test "detect prints a profile name or fails clearly" {
  define_root
  # We force the result so it is deterministic.
  define_bash
  SYSCTL_SYSTEM_NAME=ai-x88-srv run "${BASH_BIN}" "${INSTALL_SH}" detect
  [ "$status" -eq 0 ]
  [ "$output" = "ai-x88-srv" ]
}
