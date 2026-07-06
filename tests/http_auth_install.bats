#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(install) migrates a legacy enabled app onto the enabled property" {
  # Simulate an app enabled before the enabled property existed: a rendered
  # include survives but no enabled property is recorded.
  dokku http-auth:enable "$APP" u1 pass1
  $SUDO rm -f "$(property_dir "$APP")/enabled"
  assert_disabled "$APP"
  $SUDO test -f "$(http_auth_conf_path "$APP")"
  fire_install
  [ "$(http_auth_property "$APP" enabled)" = "true" ]
  assert_enabled "$APP"
}

@test "(install) leaves an app without an include untouched" {
  # An app that never used http-auth must not gain an enabled property.
  fire_install
  [ -z "$(http_auth_property "$APP" enabled)" ]
  assert_disabled "$APP"
}
