#!/usr/bin/env bats
#
# Tests for bootstrap.sh
# Requires bats-core: https://github.com/bats-core/bats-core

setup() {
  # Source without executing main (guard in bootstrap.sh handles this)
  # shellcheck source=../bootstrap.sh disable=SC1091
  source "${BATS_TEST_DIRNAME}/../bootstrap.sh"
  MOCK_BIN="$(mktemp -d)"
}

teardown() {
  rm -rf "$MOCK_BIN"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

mock_curl() {
  local http_code="$1"
  cat > "$MOCK_BIN/curl" <<EOF
#!/bin/bash
# Parse flags to write empty body to the -o destination, echo http code to stdout
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) : > "\$2"; shift 2 ;;
    *)  shift ;;
  esac
done
echo "$http_code"
EOF
  chmod +x "$MOCK_BIN/curl"
  export PATH="$MOCK_BIN:$PATH"
}

# ---------------------------------------------------------------------------
# parse_args
# ---------------------------------------------------------------------------

@test "parse_args: sets TOKEN REPO ENTRYPOINT from flags" {
  parse_args --token "tok123" --repo "owner/repo" --entrypoint "scripts/install.sh"
  [ "$TOKEN"      = "tok123"            ]
  [ "$REPO"       = "owner/repo"        ]
  [ "$ENTRYPOINT" = "scripts/install.sh" ]
}

@test "parse_args: CLI flags override env vars" {
  TOKEN="old" REPO="old/repo" ENTRYPOINT="old/script.sh"
  parse_args --token "new" --repo "new/repo" --entrypoint "new/script.sh"
  [ "$TOKEN"      = "new"          ]
  [ "$REPO"       = "new/repo"     ]
  [ "$ENTRYPOINT" = "new/script.sh" ]
}

@test "parse_args: preserves env vars when no flags given" {
  TOKEN="env-tok" REPO="env/repo" ENTRYPOINT="env/script.sh"
  parse_args
  [ "$TOKEN"      = "env-tok"     ]
  [ "$REPO"       = "env/repo"    ]
  [ "$ENTRYPOINT" = "env/script.sh" ]
}

@test "parse_args: dies on unknown argument" {
  run parse_args --unknown-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown argument"* ]]
}

# ---------------------------------------------------------------------------
# download_entrypoint
# ---------------------------------------------------------------------------

@test "download_entrypoint: succeeds on HTTP 200" {
  mock_curl 200
  local dest
  dest="$(mktemp)"
  run download_entrypoint "tok" "owner/repo" "script.sh" "$dest"
  rm -f "$dest"
  [ "$status" -eq 0 ]
}

@test "download_entrypoint: dies with auth message on HTTP 401" {
  mock_curl 401
  local dest
  dest="$(mktemp)"
  run download_entrypoint "bad-tok" "owner/repo" "script.sh" "$dest"
  rm -f "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Authentication failed"* ]]
}

@test "download_entrypoint: dies with access message on HTTP 403" {
  mock_curl 403
  local dest
  dest="$(mktemp)"
  run download_entrypoint "tok" "owner/repo" "script.sh" "$dest"
  rm -f "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Access denied"* ]]
}

@test "download_entrypoint: dies with not-found message on HTTP 404" {
  mock_curl 404
  local dest
  dest="$(mktemp)"
  run download_entrypoint "tok" "owner/repo" "script.sh" "$dest"
  rm -f "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Not found"* ]]
}

@test "download_entrypoint: dies with generic message on unexpected HTTP code" {
  mock_curl 500
  local dest
  dest="$(mktemp)"
  run download_entrypoint "tok" "owner/repo" "script.sh" "$dest"
  rm -f "$dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"500"* ]]
}

# ---------------------------------------------------------------------------
# Root check (main)
# Relies on tests running as non-root, which is always true in CI.
# ---------------------------------------------------------------------------

@test "main: exits when not running as root" {
  # Run in a clean subprocess so we don't inherit the current session's root state
  run bash -c 'source '"${BATS_TEST_DIRNAME}/../bootstrap.sh"'; main'
  [ "$status" -ne 0 ]
  [[ "$output" == *"root"* ]]
}
