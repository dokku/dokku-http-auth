#!/usr/bin/env bash
# Run on a Linux host (Ubuntu 24.04). Bootstraps Dokku natively and installs
# the plugin from the working tree. http-auth needs no supporting services.
set -euo pipefail

PLUGIN_SRC="${PLUGIN_SRC:-${GITHUB_WORKSPACE:-$(pwd)}}"
DOKKU_TAG="${DOKKU_TAG:-}"

log() { echo "-----> $*"; }

if ! command -v dokku >/dev/null 2>&1; then
  log "Preparing apt/nginx prerequisites for dokku bootstrap"
  sudo mkdir -p /etc/nginx
  sudo curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/tests/dhparam.pem -o /etc/nginx/dhparam.pem
  echo "dokku dokku/skip_key_file boolean true" | sudo debconf-set-selections
  echo "dokku dokku/hostname string dokku.test" | sudo debconf-set-selections
  echo "dokku dokku/vhost_enable boolean true" | sudo debconf-set-selections
  echo "dokku dokku/web_config boolean false" | sudo debconf-set-selections

  log "Downloading dokku bootstrap.sh"
  curl -fsSL https://raw.githubusercontent.com/dokku/dokku/master/bootstrap.sh -o /tmp/dokku-bootstrap.sh
  if [ -n "$DOKKU_TAG" ]; then
    log "Running bootstrap.sh with DOKKU_TAG=$DOKKU_TAG"
    sudo DOKKU_TAG="$DOKKU_TAG" bash /tmp/dokku-bootstrap.sh
  else
    log "Running bootstrap.sh (latest)"
    sudo bash /tmp/dokku-bootstrap.sh
  fi
else
  log "dokku already installed; skipping bootstrap"
fi

if sudo dokku plugin:installed http-auth; then
  log "http-auth plugin already installed; uninstalling first"
  sudo dokku plugin:uninstall http-auth
fi

log "Staging plugin source at /tmp/http-auth"
sudo rm -rf /tmp/http-auth
sudo cp -r "${PLUGIN_SRC}" /tmp/http-auth
sudo rm -rf /tmp/http-auth/tmp

# `dokku plugin:install` git-clones the URL, which would install committed
# HEAD rather than the working tree. Re-init the staged copy as a fresh
# single-commit repo so local uncommitted changes are exercised too.
sudo rm -rf /tmp/http-auth/.git
sudo bash -c "cd /tmp/http-auth && git init --quiet && git add -A && git -c user.name=hatest -c user.email=hatest@dokku.test commit --quiet --message 'test snapshot'"

log "Installing http-auth plugin from /tmp/http-auth"
sudo dokku plugin:install "file:///tmp/http-auth"

log "Setup complete"
