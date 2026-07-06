#!/usr/bin/env bash
# Run inside the dokku container. Installs the plugin from the bind-mounted
# /plugin-src tree.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-/plugin-src}"

log() { echo "-----> $*"; }

if dokku plugin:installed http-auth; then
  log "http-auth plugin already installed; uninstalling first"
  dokku plugin:uninstall http-auth
fi

# `dokku plugin:install` derives the destination directory name from the
# basename of the source URL, so stage the bind-mounted source at a path
# whose basename is `http-auth` before installing.
log "Staging plugin source at /tmp/http-auth"
rm -rf /tmp/http-auth
cp -r "${PLUGIN_SRC}" /tmp/http-auth
# the repo's tmp/ scratch dir (compose-mode host state) must not ship inside the plugin
rm -rf /tmp/http-auth/tmp

# `dokku plugin:install` git-clones the URL, which would install committed
# HEAD rather than the working tree. Re-init the staged copy as a fresh
# single-commit repo so local uncommitted changes are exercised too.
rm -rf /tmp/http-auth/.git
(
  cd /tmp/http-auth
  git init --quiet
  git add -A
  git -c user.name=hatest -c user.email=hatest@dokku.test commit --quiet --message "test snapshot"
)

log "Installing http-auth plugin from /tmp/http-auth"
dokku plugin:install "file:///tmp/http-auth"

log "Setup complete"
