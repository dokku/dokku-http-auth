#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(http-auth:report) error when there are no arguments" {
  run dokku http-auth:report
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(http-auth:report) error when app does not exist" {
  run dokku http-auth:report non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(http-auth:report) success when on" {
  dokku http-auth:report my_app user password
  run dokku http-auth my_app
  assert_contains "${lines[*]}" "true"
}

@test "(http-auth:report) success when off" {
  run dokku http-auth:report my_app
  assert_contains "${lines[*]}" "false"
}
