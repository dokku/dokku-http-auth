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

@test "(http-auth:add-allowed-ip) renders satisfy any, allow, and deny all" {
  run dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Adding 10.0.0.1 to allowed ip list"* ]]
  run http_auth_conf "$APP"
  [[ "$output" == *"satisfy any;"* ]]
  [[ "$output" == *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"deny all;"* ]]
}

@test "(http-auth:add-allowed-ip) is idempotent for duplicate ips" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  [ "$status" -eq 0 ]
  [ "$(http_auth_conf "$APP" | grep -c '^allow 10.0.0.1;$')" -eq 1 ]
  run dokku http-auth:report "$APP" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
}

@test "(http-auth:add-allowed-ip) fails when the address is missing" {
  run dokku http-auth:add-allowed-ip "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing ip address"* ]]
}

@test "(http-auth:add-allowed-ip) renders one allow line per allowed ip" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.2
  run http_auth_conf "$APP"
  [[ "$output" == *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"allow 10.0.0.2;"* ]]
  run dokku http-auth:report "$APP" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1 10.0.0.2" ]
}

@test "(http-auth:remove-allowed-ip) removes the allow line" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.2
  run dokku http-auth:remove-allowed-ip "$APP" 10.0.0.1
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing 10.0.0.1 from allowed ip list"* ]]
  run http_auth_conf "$APP"
  [[ "$output" != *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"allow 10.0.0.2;"* ]]
}

@test "(http-auth:remove-allowed-ip) removing the last ip drops the satisfy and deny lines" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku http-auth:remove-allowed-ip "$APP" 10.0.0.1
  run http_auth_conf "$APP"
  [[ "$output" != *"satisfy any"* ]]
  [[ "$output" != *"allow 10.0.0.1"* ]]
  [[ "$output" != *"deny all"* ]]
}

@test "(http-auth:remove-allowed-ip) fails when the address is missing" {
  run dokku http-auth:remove-allowed-ip "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing ip address"* ]]
}

@test "(http-auth:add-allowed-ip) allowed ips without users render no auth_basic block" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run http_auth_conf "$APP"
  [[ "$output" == *"satisfy any;"* ]]
  [[ "$output" != *"auth_basic"* ]]
}

@test "(http-auth:add-allowed-ip) allowed ips with users render both blocks" {
  dokku http-auth:add-user "$APP" u1 pass1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run http_auth_conf "$APP"
  [[ "$output" == *"satisfy any;"* ]]
  [[ "$output" == *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"deny all;"* ]]
  [[ "$output" == *"auth_basic"* ]]
}

@test "(http-auth:add-allowed-ip) on a disabled app implicitly creates the config" {
  dokku http-auth:disable "$APP"
  assert_disabled "$APP"
  run dokku http-auth:add-allowed-ip "$APP" 10.0.0.5
  [ "$status" -eq 0 ]
  assert_enabled "$APP"
  run http_auth_conf "$APP"
  [[ "$output" == *"allow 10.0.0.5;"* ]]
}

@test "(http-auth:add-allowed-ip) warns when the app restricts auth to domains" {
  dokku domains:add "$APP" a.example.com >/dev/null
  dokku http-auth:add-domain "$APP" a.example.com
  run dokku http-auth:add-allowed-ip "$APP" 10.0.0.6
  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed-ips apply to all domains"* ]]
}
