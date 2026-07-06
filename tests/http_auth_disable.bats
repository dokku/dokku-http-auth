#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:disable) removes the nginx include file" {
  dokku http-auth:enable "$APP"
  run dokku http-auth:disable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Disabling HTTP auth for $APP"* ]]
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
  assert_disabled "$APP"
}

@test "(http-auth:disable) when already disabled is a no-op" {
  run dokku http-auth:disable "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Authentication already disabled"* ]]
}

@test "(http-auth:off) is a deprecated alias for disable" {
  dokku http-auth:enable "$APP"
  run dokku http-auth:off "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deprecated: Please use http-auth:disable"* ]]
  assert_disabled "$APP"
}

@test "(http-auth:disable) records the disabled property" {
  dokku http-auth:enable "$APP"
  dokku http-auth:disable "$APP"
  [ "$(http_auth_property "$APP" enabled)" = "false" ]
}

@test "(http-auth:disable) keeps the htpasswd file so users survive re-enable" {
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:disable "$APP"
  $SUDO test -f "$(htpasswd_path "$APP")"
  run dokku http-auth:enable "$APP"
  [ "$status" -eq 0 ]
  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ "$output" = "u1" ]
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
}
