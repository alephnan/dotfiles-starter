#!/usr/bin/env bash
# Run only inside a disposable Linux container: tests install system packages.
set -euo pipefail
# shellcheck source=/dev/null
source /etc/os-release
if [[ "$ID" == arch ]]; then
  pacman -Syu --needed --noconfirm sudo git ca-certificates python
else
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y sudo git ca-certificates python3
fi
useradd --create-home --shell /bin/bash tester
printf 'tester ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/dotfiles-test
chmod 0440 /etc/sudoers.d/dotfiles-test
test_home="$(getent passwd tester | cut -d: -f6)"
mkdir "$test_home/dotfiles"
cp -a /source/. "$test_home/dotfiles/"
chown -R tester:tester "$test_home"
# Expand HOME in the test user's shell, not the root shell preparing the container.
# shellcheck disable=SC2016
runuser -u tester -- env HOME="$test_home" bash --noprofile --norc -c '
  set -euo pipefail
  cd "$HOME/dotfiles"
  ./bootstrap.sh --dry-run
  ./bootstrap.sh --yes
  [[ ! -d "$HOME/.cargo" && ! -d "$HOME/.rustup" ]]
  ./tests/smoke.sh 0
  ./bootstrap.sh --yes --with-dev-tools
  ./tests/smoke.sh 1
  ./bootstrap.sh --skip-packages --with-dev-tools
  ./tests/smoke.sh 1
  python3 scripts/check-privacy.py
'
