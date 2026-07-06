#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:enable) enables auth and creates the nginx include file" {
  run dokku http-auth:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Enabling HTTP auth for $APP"* ]]
  $SUDO test -f "$(http_auth_conf_path "$APP")"
  assert_enabled "$APP"
}

@test "(http-auth:enable) with credentials creates the user and renders the auth_basic block" {
  run dokku http-auth:enable "$APP" testuser testpass
  [ "$status" -eq 0 ]
  htpasswd_contents "$APP" | grep -q '^testuser:\$6\$'
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
  [[ "$output" == *"auth_basic_user_file /home/dokku/$APP/htpasswd;"* ]]
}

@test "(http-auth:enable) without credentials warns about skipping user initialization" {
  run dokku http-auth:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping user initialization"* ]]
  $SUDO test -f "$(htpasswd_path "$APP")"
  [ -z "$(htpasswd_contents "$APP")" ]
  run http_auth_conf "$APP"
  [[ "$output" != *"auth_basic"* ]]
}

@test "(http-auth:enable) when already enabled is a no-op" {
  dokku http-auth:enable "$APP"
  run dokku http-auth:enable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Authentication already enabled"* ]]
}

@test "(http-auth:enable) fails for a missing app" {
  run dokku http-auth:enable hatest-no-such-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "(http-auth:on) is a deprecated alias for enable" {
  run dokku http-auth:on "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deprecated: Please use http-auth:enable"* ]]
  assert_enabled "$APP"
}
