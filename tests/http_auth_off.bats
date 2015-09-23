#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
  dokku http-auth:on my_app user password >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(http-auth:off) error when there are no arguments" {
  run dokku http-auth:off
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(http-auth:off) error when app does not exist" {
  run dokku http-auth:off non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(http-auth:off) success" {
  run dokku http-auth:off my_app
  [[ ! -f $DOKKU_ROOT/my_app/nginx.conf.d/http-auth.conf ]]
  assert_success
}

