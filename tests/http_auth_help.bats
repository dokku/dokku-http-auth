#!/usr/bin/env bats

load 'test_helper'

@test "(http-auth) dokku http-auth prints the plugin help" {
  run dokku http-auth
  [ "$status" -eq 0 ]
  [[ "$output" == *"Manage the http-auth proxy"* ]]
}

@test "(http-auth:help) lists every subcommand" {
  run dokku http-auth:help
  [ "$status" -eq 0 ]
  for subcommand in add-allowed-ip add-domain add-user disable enable export-users import-users remove-allowed-ip remove-domain remove-user report set-domains show-config; do
    [[ "$output" == *"http-auth:${subcommand}"* ]]
  done
}
