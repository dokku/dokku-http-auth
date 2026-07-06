#!/usr/bin/env bash
# Helpers for the dokku-http-auth bats suite. Sourced by every *.bats file.

# `SUDO` is empty in compose mode (bats already runs as root in the dokku
# container) and `sudo` in native mode (files under /home/dokku and
# /var/lib/dokku need elevation to read).
SUDO="${SUDO:-}"

new_app_name() {
  echo "hatest-${BATS_TEST_NUMBER:-0}-$(date +%s)-${RANDOM}"
}

create_app() {
  local app="$1"
  dokku apps:create "$app"
}

cleanup_app() {
  local app="$1"
  if dokku apps:exists "$app" >/dev/null 2>&1; then
    dokku --force apps:destroy "$app" >/dev/null 2>&1 || true
  fi
}

http_auth_conf_path() {
  echo "/home/dokku/$1/nginx.conf.d/http-auth.conf"
}

htpasswd_path() {
  echo "/home/dokku/$1/htpasswd"
}

property_dir() {
  echo "/var/lib/dokku/config/http-auth/$1"
}

http_auth_conf() {
  $SUDO cat "$(http_auth_conf_path "$1")"
}

htpasswd_contents() {
  $SUDO cat "$(htpasswd_path "$1")"
}

http_auth_enabled() {
  dokku http-auth:report "$1" --http-auth-enabled
}

assert_enabled() {
  [ "$(http_auth_enabled "$1")" = "true" ]
}

assert_disabled() {
  [ "$(http_auth_enabled "$1")" = "false" ]
}
