#!/usr/bin/env bats

setup() {
  export NO_COLOR=1
}

define_root() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  INSTALL_SH="${ROOT_DIR}/install.sh"
}

@test "install.sh list includes ai-x88-srv profile (supports performanc typo)" {
  define_root
  run bash "${INSTALL_SH}" list
  [ "$status" -eq 0 ]
  [[ "$output" == *"ai-x88-srv"* ]]
}

@test "dry-run install does not require root" {
  define_root
  run bash "${INSTALL_SH}" --dry-run install dell-xps
  [ "$status" -eq 0 ]
  [[ "$output" == *"[DRY RUN]"* ]]
}

@test "auto-detect can be overridden via SYSCTL_SYSTEM_NAME" {
  define_root
  SYSCTL_SYSTEM_NAME=ai-x88-srv run bash "${INSTALL_SH}" --dry-run --auto-detect install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing sysctl settings for system: ai-x88-srv"* ]]
  # Source file may be the legacy typo, but destination should be normalized.
  [[ "$output" == *"99-ai-x88-srv-performanc.conf"* || "$output" == *"99-ai-x88-srv-performance.conf"* ]]
  [[ "$output" == *"/etc/sysctl.d/99-ai-x88-srv-performance.conf"* ]]
}

@test "detect prints a profile name or fails clearly" {
  define_root
  # We force the result so it is deterministic.
  SYSCTL_SYSTEM_NAME=ai-x88-srv run bash "${INSTALL_SH}" detect
  [ "$status" -eq 0 ]
  [ "$output" = "ai-x88-srv" ]
}
