#!/usr/bin/env bats
# Exercises the privileged bin/set-htpasswd helper directly, including its
# app-name validation - the security boundary that keeps every write confined
# to /etc/nginx/http-auth.

load 'test_helper'

setup() {
  APP="$(new_app_name)"
}

teardown() {
  $SUDO "$(set_htpasswd_helper)" remove "$APP" 2>/dev/null || true
}

@test "(set-htpasswd) write round-trips stdin to the app's htpasswd with mode 644" {
  echo 'u1:$6$hash' | $SUDO "$(set_htpasswd_helper)" write "$APP"
  $SUDO test -f "$(htpasswd_path "$APP")"
  [ "$(htpasswd_contents "$APP")" = 'u1:$6$hash' ]
  [ "$($SUDO stat -c '%a' "$(htpasswd_path "$APP")")" = "644" ]
  [ "$($SUDO stat -c '%a' "$(htpasswd_dir "$APP")")" = "755" ]
}

@test "(set-htpasswd) ensure creates an empty htpasswd without clobbering an existing one" {
  echo 'u1:$6$hash' | $SUDO "$(set_htpasswd_helper)" write "$APP"
  $SUDO "$(set_htpasswd_helper)" ensure "$APP"
  [ "$(htpasswd_contents "$APP")" = 'u1:$6$hash' ]
}

@test "(set-htpasswd) remove deletes the app's htpasswd directory" {
  echo 'u1:$6$hash' | $SUDO "$(set_htpasswd_helper)" write "$APP"
  $SUDO test -d "$(htpasswd_dir "$APP")"
  $SUDO "$(set_htpasswd_helper)" remove "$APP"
  $SUDO test ! -d "$(htpasswd_dir "$APP")"
}

@test "(set-htpasswd) rejects an app name containing a slash" {
  run bash -c "echo pwned | $(set_htpasswd_helper) write 'foo/bar'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid app name"* ]]
}

@test "(set-htpasswd) rejects a path-traversal app name and writes nothing outside the tree" {
  run bash -c "echo pwned | $(set_htpasswd_helper) write '../../../../../../etc/cron.d/pwn'"
  [ "$status" -ne 0 ]
  test ! -f /etc/cron.d/pwn
}

@test "(set-htpasswd) rejects an empty app name" {
  run bash -c "echo pwned | $(set_htpasswd_helper) write ''"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing app name"* ]]
}
