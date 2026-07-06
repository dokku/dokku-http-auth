#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
}

teardown() {
  cleanup_app "$APP"
}

@test "(nginx-pre-reload) re-renders an emptied include for an enabled app" {
  dokku http-auth:enable "$APP" u1 pass1
  $SUDO truncate -s 0 "$(http_auth_conf_path "$APP")"
  [ -z "$(http_auth_conf "$APP")" ]
  fire_nginx_pre_reload "$APP"
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
  [[ "$output" == *"auth_basic_user_file /home/dokku/$APP/htpasswd;"* ]]
}

@test "(nginx-pre-reload) removes the include for a disabled app" {
  dokku http-auth:enable "$APP"
  dokku http-auth:disable "$APP"
  $SUDO mkdir -p "$(dirname "$(http_auth_conf_path "$APP")")"
  echo 'auth_basic "Restricted";' | $SUDO tee "$(http_auth_conf_path "$APP")" >/dev/null
  $SUDO test -f "$(http_auth_conf_path "$APP")"
  fire_nginx_pre_reload "$APP"
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
}

@test "(nginx-pre-reload) heals an install broken by the pre-fix empty-config bug" {
  # A healthy enable: user in htpasswd, include with auth_basic, enabled property set.
  dokku http-auth:enable "$APP" u1 pass1
  # Reconstruct the exact state shipped by the buggy 0.10.0: the user survives in
  # htpasswd, the rendered include is empty, and the enabled property predates
  # this fix so it does not exist yet.
  $SUDO truncate -s 0 "$(http_auth_conf_path "$APP")"
  $SUDO rm -f "$(property_dir "$APP")/enabled"
  assert_disabled "$APP"
  # A plugin re-install migrates the enabled flag from the surviving include...
  fire_install
  [ "$(http_auth_property "$APP" enabled)" = "true" ]
  # ...and the next nginx rebuild re-renders the include from state.
  fire_nginx_pre_reload "$APP"
  run http_auth_conf "$APP"
  [[ "$output" == *"auth_basic"* ]]
  [[ "$output" == *"auth_basic_user_file /home/dokku/$APP/htpasswd;"* ]]
}
