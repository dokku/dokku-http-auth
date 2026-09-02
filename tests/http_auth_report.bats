#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:report) renders a report for a single app" {
  run dokku http-auth:report "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP http-auth information"* ]]
  [[ "$output" == *"Http auth enabled"* ]]
  [[ "$output" == *"Http auth allowed ips"* ]]
  [[ "$output" == *"Http auth domains"* ]]
  [[ "$output" == *"Http auth users"* ]]
}

@test "(http-auth:report) without an app iterates all apps" {
  run dokku http-auth:report
  [ "$status" -eq 0 ]
  [[ "$output" == *"$APP http-auth information"* ]]
}

@test "(http-auth:report) --http-auth-enabled reflects enable and disable" {
  run dokku http-auth:report "$APP" --http-auth-enabled
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
  dokku http-auth:enable "$APP"
  run dokku http-auth:report "$APP" --http-auth-enabled
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "(http-auth:report) --http-auth-allowed-ips is empty but successful with no ips" {
  run dokku http-auth:report "$APP" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  dokku http-auth:enable "$APP"
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run dokku http-auth:report "$APP" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
}

@test "(http-auth:report) --http-auth-users is empty but successful with no users" {
  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(http-auth:report) --http-auth-users lists users" {
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2
  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ "$output" = "u1 u2" ]
}

@test "(http-auth:report) rejects an invalid flag" {
  run dokku http-auth:report "$APP" --invalid-flag
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid flag passed, valid flags:"* ]]
}

@test "(http-auth:report) fails for a missing app" {
  run dokku http-auth:report hatest-no-such-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "(http-auth:report) --format json emits a json object" {
  run dokku http-auth:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":"false"'* ]]
  [[ "$output" == *'"allowed-ips":""'* ]]
  [[ "$output" == *'"domains":""'* ]]
  [[ "$output" == *'"users":""'* ]]

  dokku http-auth:enable "$APP"
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1

  run dokku http-auth:report "$APP" --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":"true"'* ]]
  [[ "$output" == *'"allowed-ips":"10.0.0.1"'* ]]
}

@test "(http-auth:report) --format json rejects an info flag" {
  run dokku http-auth:report "$APP" --format json --http-auth-enabled
  [ "$status" -ne 0 ]
  [[ "$output" == *"--format flag cannot be specified when specifying an info flag"* ]]
}

@test "(http-auth:report) without an app emits one json object per app" {
  run dokku http-auth:report --format json
  [ "$status" -eq 0 ]
  [[ "$output" == *'"enabled":"false"'* ]]

  # every emitted line is a valid JSON object
  run /bin/bash -c "dokku http-auth:report --format json | jq -e . >/dev/null"
  [ "$status" -eq 0 ]
}

@test "(http-auth:report) --global --format json returns an empty object" {
  run dokku http-auth:report --global --format json
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "(dokku report) includes an http-auth section" {
  run dokku report "$APP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"http-auth information"* ]]
}
