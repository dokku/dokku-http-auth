#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:show-config) fails when auth is not enabled" {
  run dokku http-auth:show-config "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No nginx.conf exists for $APP"* ]]
}

@test "(http-auth:show-config) prints the rendered config" {
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run dokku http-auth:show-config "$APP"
  [ "$status" -eq 0 ]
  [ "$output" = "$(http_auth_conf "$APP")" ]
}
