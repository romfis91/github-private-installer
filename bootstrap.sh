#!/bin/bash
# Universal App Installer Bootstrap
#
# Downloads an entrypoint script from a private GitHub repository
# and hands off all control to it. App-specific logic (domain, ports, etc.)
# is the entrypoint's responsibility.
#
# Usage — interactive:
#   curl -fsSL https://raw.githubusercontent.com/romfis91/github-private-installer/main/bootstrap.sh | sudo bash
#
# Usage — with arguments:
#   curl -fsSL https://raw.githubusercontent.com/romfis91/github-private-installer/main/bootstrap.sh | \
#     sudo bash -s -- \
#       --token  ghp_xxx \
#       --repo   owner/repo \
#       --entrypoint scripts/install.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[init]${NC} $*"; }
warn() { echo -e "${YELLOW}[init]${NC} $*"; }
die()  { echo -e "${RED}[init] ERROR:${NC} $*" >&2; exit 1; }

parse_args() {
  TOKEN="${TOKEN:-}"
  REPO="${REPO:-}"
  ENTRYPOINT="${ENTRYPOINT:-}"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --token)      TOKEN="$2";      shift 2 ;;
      --repo)       REPO="$2";       shift 2 ;;
      --entrypoint) ENTRYPOINT="$2"; shift 2 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
}

prompt_missing() {
  if [ -z "$TOKEN" ]; then
    read -rp "GitHub token (repo scope): " TOKEN
    [ -n "$TOKEN" ] || die "Token cannot be empty"
  fi

  if [ -z "$REPO" ]; then
    read -rp "GitHub repository (e.g. owner/repo): " REPO
    [ -n "$REPO" ] || die "Repository cannot be empty"
  fi

  if [ -z "$ENTRYPOINT" ]; then
    read -rp "Entrypoint script path (e.g. scripts/install.sh): " ENTRYPOINT
    [ -n "$ENTRYPOINT" ] || die "Entrypoint cannot be empty"
  fi
}

download_entrypoint() {
  local token="$1" repo="$2" entrypoint="$3" dest="$4"

  info "Downloading ${entrypoint} from ${repo}..."

  local http_code
  http_code=$(curl -fsSL \
    -H "Authorization: token ${token}" \
    -H "Accept: application/vnd.github.v3.raw" \
    -w "%{http_code}" \
    -o "$dest" \
    "https://api.github.com/repos/${repo}/contents/${entrypoint}" 2>/dev/null) || true

  case "$http_code" in
    200) ;;
    401) die "Authentication failed — check your token" ;;
    403) die "Access denied — token lacks repo scope" ;;
    404) die "Not found — check repo name and entrypoint path" ;;
    *)   die "Download failed (HTTP ${http_code})" ;;
  esac
}

main() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "Run as root: sudo bash"

  echo ""
  echo "  App Installer Bootstrap"
  echo ""

  parse_args "$@"
  prompt_missing

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT

  download_entrypoint "$TOKEN" "$REPO" "$ENTRYPOINT" "$tmpfile"

  info "Handing off to entrypoint..."
  echo ""
  GITHUB_TOKEN="$TOKEN" bash "$tmpfile"
}

# Allow sourcing for tests without auto-executing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi