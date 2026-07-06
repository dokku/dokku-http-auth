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

@test "(install) writes the sudoers entry for the htpasswd helper" {
  fire_install
  $SUDO test -f /etc/sudoers.d/dokku-http-auth
}

@test "(install) relocates a legacy enabled app's htpasswd into /etc/nginx" {
  # Reconstruct the pre-move layout: htpasswd and include live in the app home
  # directory and the include points at the old path. migrate-enabled records
  # the enabled state from the surviving include, then the htpasswd migration
  # copies the file forward and repoints the include.
  local legacy conf
  legacy="$(legacy_htpasswd_path "$APP")"
  conf="$(http_auth_conf_path "$APP")"
  echo 'u1:$6$seededhash' | $SUDO tee "$legacy" >/dev/null
  $SUDO mkdir -p "$(dirname "$conf")"
  { echo 'auth_basic "Restricted";'; echo "auth_basic_user_file $legacy;"; } | $SUDO tee "$conf" >/dev/null

  fire_install

  $SUDO test -f "$(htpasswd_path "$APP")"
  [ "$(htpasswd_contents "$APP")" = 'u1:$6$seededhash' ]
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP");"* ]]
}

@test "(install) does not resurrect auth for a disabled app with a lingering htpasswd" {
  # An app enabled then disabled leaves its htpasswd behind but removes the
  # include. A plugin upgrade must not re-render an include for it.
  dokku http-auth:enable "$APP"
  dokku http-auth:disable "$APP"
  $SUDO rm -rf "$(htpasswd_dir "$APP")"
  echo 'u1:$6$seededhash' | $SUDO tee "$(legacy_htpasswd_path "$APP")" >/dev/null

  fire_install

  assert_disabled "$APP"
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
  $SUDO test ! -d "$(htpasswd_dir "$APP")"
}
