#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=bootstrap.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/bootstrap.sh"
scan_dir="$(mktemp -d)"
trap 'rm -rf -- "$scan_dir"' EXIT
download_verified "$GITLEAKS_URL" "$GITLEAKS_SHA256" "$scan_dir/gitleaks.tar.gz"
tar -xzf "$scan_dir/gitleaks.tar.gz" -C "$scan_dir" gitleaks
"$scan_dir/gitleaks" dir --redact --no-banner "$DOTFILES_DIR"
if git -C "$DOTFILES_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then
  "$scan_dir/gitleaks" git --redact --no-banner --log-opts=--all "$DOTFILES_DIR"
fi
