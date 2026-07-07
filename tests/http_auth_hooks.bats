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

@test "(http-auth) post-delete destroys the plugin properties and htpasswd on apps:destroy" {
  dokku http-auth:enable "$APP" u1 pass1
  $SUDO test -d "$(property_dir "$APP")"
  $SUDO test -d "$(htpasswd_dir "$APP")"
  dokku --force apps:destroy "$APP"
  $SUDO test ! -d "$(property_dir "$APP")"
  $SUDO test ! -d "$(htpasswd_dir "$APP")"
}

@test "(http-auth) post-app-clone-setup clones properties and htpasswd to the new app" {
  APP2="$(new_app_name)"
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku apps:clone --skip-deploy "$APP" "$APP2"
  run dokku http-auth:report "$APP2" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
  assert_enabled "$APP2"
  # the htpasswd is copied into the new app's own directory and the include
  # references that path, not the source app's
  $SUDO test -f "$(htpasswd_path "$APP2")"
  htpasswd_contents "$APP2" | grep -q '^u1:\$6\$'
  run http_auth_conf "$APP2"
  [[ "$output" == *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP2");"* ]]
}

@test "(http-auth) post-app-clone-setup clones auth domains to the new app" {
  APP2="$(new_app_name)"
  dokku domains:add "$APP" a.example.com >/dev/null
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:add-domain "$APP" a.example.com
  dokku apps:clone --skip-deploy "$APP" "$APP2"
  run dokku http-auth:report "$APP2" --http-auth-domains
  [ "$status" -eq 0 ]
  [ "$output" = "a.example.com" ]
  # the include re-renders with the host-gated block for the cloned app
  run http_auth_conf "$APP2"
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
}

@test "(http-auth) post-app-rename-setup moves properties and htpasswd to the new name" {
  APP2="$(new_app_name)"
  dokku http-auth:enable "$APP" u1 pass1
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku apps:rename --skip-deploy "$APP" "$APP2"
  run dokku http-auth:report "$APP2" --http-auth-allowed-ips
  [ "$status" -eq 0 ]
  [ "$output" = "10.0.0.1" ]
  $SUDO test ! -d "$(property_dir "$APP")"
  # the htpasswd dir moves to the new name and the include repoints
  $SUDO test ! -d "$(htpasswd_dir "$APP")"
  $SUDO test -f "$(htpasswd_path "$APP2")"
  htpasswd_contents "$APP2" | grep -q '^u1:\$6\$'
  run http_auth_conf "$APP2"
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP2");"* ]]
}

@test "(http-auth) auth credentials survive an app rename (issue #18)" {
  APP2="$(new_app_name)"
  dokku http-auth:enable "$APP" u1 pass1
  # the exact hashed credentials nginx authenticates against
  local before
  before="$(htpasswd_contents "$APP")"
  dokku apps:rename --skip-deploy "$APP" "$APP2"
  # byte-identical htpasswd => the same user/password still authenticates
  # instead of returning permission denied
  [ "$(htpasswd_contents "$APP2")" = "$before" ]
  assert_enabled "$APP2"
  # the include references the new app's htpasswd with auth_basic on, not a
  # stale path nginx cannot read
  run http_auth_conf "$APP2"
  [[ "$output" == *"auth_basic"* ]]
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP2");"* ]]
}
