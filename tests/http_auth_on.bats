#!/usr/bin/env bats
load test_helper

setup() {
  dokku apps:create my_app >&2
}

teardown() {
  rm "$DOKKU_ROOT/my_app" -rf
}

@test "(http-auth:enable) error when there are no arguments" {
  run dokku http-auth:enable
  assert_contains "${lines[*]}" "Please specify an app to run the command on"
}

@test "(http-auth:enable) error when app does not exist" {
  run dokku http-auth:enable non_existing_app
  assert_contains "${lines[*]}" "App non_existing_app does not exist"
}

@test "(http-auth:enable) error when username not provided" {
  run dokku http-auth:enable my_app
  assert_contains "${lines[*]}" "Please provide a username and a password"
}

@test "(http-auth:enable) error when password not provided" {
  run dokku http-auth:enable my_app user
  assert_contains "${lines[*]}" "Please provide a username and a password"
}

@test "(http-auth:enable) success" {
  run dokku http-auth:enable my_app user password
  assert_exists "$DOKKU_ROOT/my_app/nginx.conf.d/http-auth.conf"
  htpasswd=$(< "$DOKKU_ROOT/my_app/htpasswd")
  assert_equal "$htpasswd" 'user:$6$aXBp2sHg8$EV/2iLc1/26QhyVGjagPvcnaqKpTh1F997mRui43F1ioyH5Nvvn7JA83sJAVJypjHjVvGMBUVwgovXm0BC4Wp0'
  assert_success
}

