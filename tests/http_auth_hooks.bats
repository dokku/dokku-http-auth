#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  APP2=""
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
  if [ -n "$APP2" ]; then
    cleanup_app "$APP2"
  fi
}

@test "(http-auth) post-delete destroys the plugin properties on apps:destroy" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  $SUDO test -d "$(property_dir "$APP")"
  dokku --force apps:destroy "$APP"
  $SUDO test ! -d "$(property_dir "$APP")"
}

@test "(http-auth) post-app-clone-setup clones the plugin properties to the new app" {
  APP2="$(new_app_name)"
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku apps:clone --skip-deploy "$APP" "$APP2"
  run dokku http-auth:report "$APP2" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
  # apps:clone copies the app directory, so the rendered config and the
  # enabled state travel with the app
  assert_enabled "$APP2"
  run http_auth_conf "$APP2"
  [[ "$output" == *"allow 10.0.0.1;"* ]]
}

@test "(http-auth) post-app-rename-setup moves the plugin properties to the new name" {
  APP2="$(new_app_name)"
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku apps:rename --skip-deploy "$APP" "$APP2"
  run dokku http-auth:report "$APP2" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
  $SUDO test ! -d "$(property_dir "$APP")"
}
