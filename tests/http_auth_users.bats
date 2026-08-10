#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  APP2=""
  create_app "$APP"
  dokku http-auth:enable "$APP"
}

teardown() {
  cleanup_app "$APP"
  if [ -n "$APP2" ]; then
    cleanup_app "$APP2"
  fi
}

@test "(http-auth:add-user) adds an htpasswd entry with a sha-512 hash" {
  run dokku http-auth:add-user "$APP" u1 pass1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Adding u1 to basic auth list"* ]]
  htpasswd_contents "$APP" | grep -q '^u1:\$6\$'
}

@test "(http-auth:add-user) renders the auth_basic block into the config" {
  dokku http-auth:add-user "$APP" u1 pass1
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP");"* ]]
}

@test "(http-auth:add-user) replaces the password of an existing user" {
  dokku http-auth:add-user "$APP" u1 pass1
  local first_entry="$(htpasswd_contents "$APP" | grep '^u1:')"
  dokku http-auth:add-user "$APP" u1 pass2
  local second_entry="$(htpasswd_contents "$APP" | grep '^u1:')"
  [ "$(htpasswd_contents "$APP" | grep -c '^u1:')" -eq 1 ]
  [ "$first_entry" != "$second_entry" ]
}

@test "(http-auth:add-user) on a disabled app enables auth" {
  dokku http-auth:disable "$APP"
  assert_disabled "$APP"
  run dokku http-auth:add-user "$APP" u1 pass1
  [ "$status" -eq 0 ]
  assert_enabled "$APP"
  htpasswd_contents "$APP" | grep -q '^u1:\$6\$'
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
}

@test "(http-auth:add-user) enables auth on an app that never had it enabled" {
  APP2="$(new_app_name)"
  create_app "$APP2"
  run dokku http-auth:add-user "$APP2" u1 pass1
  [ "$status" -eq 0 ]
  assert_enabled "$APP2"
  run http_auth_conf "$APP2"
  [[ "$output" == *"auth_basic"* ]]
}

@test "(http-auth:add-user) fails when the username is missing" {
  run dokku http-auth:add-user "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing username"* ]]
}

@test "(http-auth:add-user) fails when the password is missing" {
  run dokku http-auth:add-user "$APP" u1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing password"* ]]
}

@test "(http-auth:remove-user) removes the htpasswd entry" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-user "$APP" u2 pass2
  run dokku http-auth:remove-user "$APP" u1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing u1 from basic auth list"* ]]
  run dokku http-auth:report "$APP" --http-auth-users
  [ "$status" -eq 0 ]
  [ "$output" = "u2" ]
}

@test "(http-auth:remove-user) removing the last user drops the auth_basic block" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:remove-user "$APP" u1
  run http_auth_conf "$APP"
  [[ "$output" != *"auth_basic"* ]]
}

@test "(http-auth:remove-user) prunes a user on a disabled app without enabling auth" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:disable "$APP"
  run dokku http-auth:remove-user "$APP" u1
  [ "$status" -eq 0 ]
  # removing config must not turn auth back on, and must not resurrect the include
  assert_disabled "$APP"
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
  [ -z "$(htpasswd_contents "$APP")" ]
}

@test "(http-auth:remove-user) fails when the username is missing" {
  run dokku http-auth:remove-user "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing username"* ]]
}
