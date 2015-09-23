#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(http-auth) error when there are no arguments" {
  run dokku http-auth
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(http-auth) error when app does not exist" {
  run dokku http-auth non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(http-auth) success when on" {
  dokku http-auth:on my_app user password
  run dokku http-auth my_app
  assert_contains "${lines[*]}" "on"
}

@test "(http-auth) success when off" {
  run dokku http-auth my_app
  assert_contains "${lines[*]}" "off"
}
