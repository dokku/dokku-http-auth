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

# The htpasswd now lives under a root-owned /etc/nginx tree so the nginx worker
# can read it; the legacy location was the app home directory.
htpasswd_dir() {
  echo "/etc/nginx/http-auth/$1"
}

htpasswd_path() {
  echo "$(htpasswd_dir "$1")/htpasswd"
}

legacy_htpasswd_path() {
  echo "/home/dokku/$1/htpasswd"
}

set_htpasswd_helper() {
  echo "/var/lib/dokku/plugins/available/http-auth/bin/set-htpasswd"
}

property_dir() {
  echo "/var/lib/dokku/config/http-auth/$1"
}

http_auth_property() {
  $SUDO cat "$(property_dir "$1")/$2" 2>/dev/null || true
}

# The bats suite never deploys, so plugin triggers are invoked directly. dokku's
# CLI normally exports the plugin environment; the bats shell does not, so set it
# here. Paths are the standard install layout, identical in compose and native
# modes. The plugin's own trigger scripts are run (rather than `plugn trigger`,
# which fans out to every plugin) to keep each assertion scoped to http-auth.
dokku_plugin_env() {
  $SUDO env \
    DOKKU_ROOT=/home/dokku \
    DOKKU_LIB_ROOT=/var/lib/dokku \
    PLUGIN_PATH=/var/lib/dokku/plugins \
    PLUGIN_AVAILABLE_PATH=/var/lib/dokku/plugins/available \
    PLUGIN_ENABLED_PATH=/var/lib/dokku/plugins/enabled \
    PLUGIN_CORE_PATH=/var/lib/dokku/core-plugins \
    PLUGIN_CORE_AVAILABLE_PATH=/var/lib/dokku/core-plugins/available \
    "$@"
}

# Re-render the app's nginx include the way an nginx rebuild would.
fire_nginx_pre_reload() {
  dokku_plugin_env /var/lib/dokku/plugins/available/http-auth/nginx-pre-reload "$1" "" "" >/dev/null
}

# Re-run the plugin's install trigger the way a `dokku plugin:install` upgrade
# does; used to exercise the http-auth enabled-state migration.
fire_install() {
  dokku_plugin_env /var/lib/dokku/plugins/available/http-auth/install >/dev/null
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
