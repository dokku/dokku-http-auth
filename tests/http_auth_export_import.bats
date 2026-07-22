#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  dokku http-auth:enable "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:export-users) streams htpasswd user:hash entries to stdout" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2

  local out
  out="$(mktemp)"
  run bash -c "dokku http-auth:export-users '$APP' >'$out'"
  [ "$status" -eq 0 ]
  grep -q '^u1:\$6\$' "$out"
  grep -q '^u2:\$6\$' "$out"
  [ "$(wc -l <"$out")" -eq 2 ]
}

@test "(http-auth:export-users) writes only the entries to stdout" {
  dokku http-auth:add-user "$APP" u1 pass1

  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  run bash -c "dokku http-auth:export-users '$APP' >'$out' 2>'$err'"
  [ "$status" -eq 0 ]
  # a clean stdout is what lets `export-users | import-users` work
  [ "$(wc -l <"$out")" -eq 1 ]
  grep -q '^u1:' "$out"
}

@test "(http-auth:export-users) still exports users when auth is disabled" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:disable "$APP"

  local out
  out="$(mktemp)"
  run bash -c "dokku http-auth:export-users '$APP' >'$out'"
  [ "$status" -eq 0 ]
  grep -q '^u1:\$6\$' "$out"
}

@test "(http-auth:export-users) warns and emits nothing when there are no users" {
  local out err
  out="$(mktemp)"
  err="$(mktemp)"
  run bash -c "dokku http-auth:export-users '$APP' >'$out' 2>'$err'"
  [ "$status" -eq 0 ]
  [ ! -s "$out" ]
  grep -q "nothing to export" "$err"
}

@test "(http-auth:export-users) fails for a nonexistent app" {
  run dokku http-auth:export-users hatest-no-such-app
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "(http-auth:import-users) upserts imported users by default" {
  dokku http-auth:add-user "$APP" u1 pass1

  run dokku http-auth:import-users "$APP" <<< $'u2:hash2\nu3:hash3'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing 2 http-auth user(s)"* ]]

  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ "$output" = "u1 u2 u3" ]
}

@test "(http-auth:import-users) upsert overrides an existing user and keeps the rest" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2

  run dokku http-auth:import-users "$APP" <<< 'u1:rehashed'
  [ "$status" -eq 0 ]
  [ "$(htpasswd_contents "$APP" | grep -c '^u1:')" -eq 1 ]
  [ "$(htpasswd_contents "$APP" | grep '^u1:')" = "u1:rehashed" ]
  htpasswd_contents "$APP" | grep -q '^u2:\$6\$'
}

@test "(http-auth:import-users --replace) replaces all users with the imported set" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2

  run dokku http-auth:import-users "$APP" --replace <<< 'u3:hash3'
  [ "$status" -eq 0 ]

  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ "$output" = "u3" ]
}

@test "(http-auth:import-users) enables auth when the app has it disabled" {
  dokku http-auth:disable "$APP"
  assert_disabled "$APP"

  run dokku http-auth:import-users "$APP" <<< 'u1:hash1'
  [ "$status" -eq 0 ]
  assert_enabled "$APP"

  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
}

@test "(http-auth:import-users) rejects a malformed entry and leaves users unchanged" {
  dokku http-auth:add-user "$APP" u1 pass1
  local before
  before="$(htpasswd_contents "$APP")"

  run dokku http-auth:import-users "$APP" <<< 'not-an-entry'
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid htpasswd entry"* ]]
  [ "$(htpasswd_contents "$APP")" = "$before" ]
}

@test "(http-auth:import-users) fails when stdin has no entries" {
  run dokku http-auth:import-users "$APP" </dev/null
  [ "$status" -ne 0 ]
  [[ "$output" == *"No htpasswd entries provided on stdin"* ]]
}

@test "(http-auth:import-users) fails for a nonexistent app" {
  run dokku http-auth:import-users hatest-no-such-app <<< 'u1:hash1'
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "(http-auth:export-users) round-trips through import-users into another app" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2

  local out
  out="$(mktemp)"
  run bash -c "dokku http-auth:export-users '$APP' >'$out'"
  [ "$status" -eq 0 ]

  local app2
  app2="$(new_app_name)"
  create_app "$app2"
  run bash -c "dokku http-auth:import-users '$app2' <'$out'"
  local import_status="$status"

  local users1 users2 contents1 contents2
  users1="$(dokku http-auth:report "$APP" --http-auth-users)"
  users2="$(dokku http-auth:report "$app2" --http-auth-users 2>/dev/null || true)"
  contents1="$(htpasswd_contents "$APP")"
  contents2="$(htpasswd_contents "$app2")"
  cleanup_app "$app2"

  [ "$import_status" -eq 0 ]
  # export then re-import reproduces the same users and the same hashes
  [ "$users1" = "u1 u2" ]
  [ "$users1" = "$users2" ]
  [ "$contents1" = "$contents2" ]
}
