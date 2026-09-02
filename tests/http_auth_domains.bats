#!/usr/bin/env bats

load 'test_helper'

setup() {
  APP="$(new_app_name)"
  create_app "$APP"
  # attach vhosts so add-domain/set-domains validation (which checks the app's
  # actual domains) has something to match; the suite never deploys.
  dokku domains:add "$APP" a.example.com b.example.com >/dev/null
  dokku http-auth:enable "$APP" u1 pass1
}

teardown() {
  cleanup_app "$APP"
}

@test "(http-auth:add-domain) renders a host-gated realm variable" {
  run dokku http-auth:add-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"Adding a.example.com to auth domain list"* ]]
  run http_auth_conf "$APP"
  [[ "$output" == *'set $dokku_auth_realm off;'* ]]
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
  [[ "$output" == *'set $dokku_auth_realm "Restricted";'* ]]
  [[ "$output" == *'auth_basic           $dokku_auth_realm;'* ]]
  [[ "$output" == *"auth_basic_user_file $(htpasswd_path "$APP");"* ]]
  # the plain app-wide realm must not be present when domains are set
  [[ "$output" != *'auth_basic           "Restricted";'* ]]
}

@test "(http-auth) with no domains renders the plain auth_basic block" {
  run http_auth_conf "$APP"
  [[ "$output" == *'auth_basic           "Restricted";'* ]]
  [[ "$output" != *'dokku_auth_realm'* ]]
}

@test "(http-auth:add-domain) renders one if block per domain" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:add-domain "$APP" b.example.com
  run http_auth_conf "$APP"
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
  [[ "$output" == *'if ($host = "b.example.com") {'* ]]
}

@test "(http-auth:add-domain) is idempotent for duplicate domains" {
  dokku http-auth:add-domain "$APP" a.example.com
  run dokku http-auth:add-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  [ "$(http_auth_conf "$APP" | grep -c 'if (\$host = "a.example.com") {')" -eq 1 ]
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$status" -eq 0 ]
  [ "$output" = "a.example.com" ]
}

@test "(http-auth:add-domain) lowercases the domain" {
  run dokku http-auth:add-domain "$APP" A.Example.COM
  [ "$status" -eq 0 ]
  run http_auth_conf "$APP"
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
  [[ "$output" != *"A.Example.COM"* ]]
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$output" = "a.example.com" ]
}

@test "(http-auth:add-domain) fails when the domain is not attached to the app" {
  run dokku http-auth:add-domain "$APP" nope.example.com
  [ "$status" -ne 0 ]
  [[ "$output" == *"nope.example.com is not a domain of $APP"* ]]
}

@test "(http-auth:add-domain) fails when the domain is missing" {
  run dokku http-auth:add-domain "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing domain"* ]]
}

@test "(http-auth:add-domain) on a disabled app implicitly enables auth" {
  dokku http-auth:disable "$APP"
  assert_disabled "$APP"
  run dokku http-auth:add-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  assert_enabled "$APP"
  run http_auth_conf "$APP"
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
}

@test "(http-auth:add-domain) warns when the app already has allowed ips" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  run dokku http-auth:add-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"allowed-ips apply to all domains"* ]]
}

@test "(http-auth:add-domain) combined with allowed ips renders both blocks" {
  dokku http-auth:add-allowed-ip "$APP" 10.0.0.1
  dokku http-auth:add-domain "$APP" a.example.com
  run http_auth_conf "$APP"
  [[ "$output" == *"satisfy any;"* ]]
  [[ "$output" == *"allow 10.0.0.1;"* ]]
  [[ "$output" == *"deny all;"* ]]
  [[ "$output" == *'if ($host = "a.example.com") {'* ]]
  [[ "$output" == *'auth_basic           $dokku_auth_realm;'* ]]
}

@test "(http-auth:set-domains) replaces the domain list" {
  dokku http-auth:add-domain "$APP" a.example.com
  run dokku http-auth:set-domains "$APP" b.example.com
  [ "$status" -eq 0 ]
  run http_auth_conf "$APP"
  [[ "$output" == *'if ($host = "b.example.com") {'* ]]
  [[ "$output" != *'if ($host = "a.example.com") {'* ]]
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$output" = "b.example.com" ]
}

@test "(http-auth:set-domains) with no domains clears back to the plain block" {
  dokku http-auth:add-domain "$APP" a.example.com
  run dokku http-auth:set-domains "$APP"
  [ "$status" -eq 0 ]
  run http_auth_conf "$APP"
  [[ "$output" == *'auth_basic           "Restricted";'* ]]
  [[ "$output" != *'dokku_auth_realm'* ]]
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(http-auth:set-domains) dedupes repeated domains" {
  run dokku http-auth:set-domains "$APP" a.example.com A.Example.COM
  [ "$status" -eq 0 ]
  [ "$(http_auth_conf "$APP" | grep -c 'if (\$host = "a.example.com") {')" -eq 1 ]
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$output" = "a.example.com" ]
}

@test "(http-auth:set-domains) fails when any domain is not attached" {
  run dokku http-auth:set-domains "$APP" a.example.com nope.example.com
  [ "$status" -ne 0 ]
  [[ "$output" == *"nope.example.com is not a domain of $APP"* ]]
  # the whole operation must be rejected, leaving no domains set
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "(http-auth:remove-domain) removes only the targeted if block" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:add-domain "$APP" b.example.com
  run dokku http-auth:remove-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removing a.example.com from auth domain list"* ]]
  run http_auth_conf "$APP"
  [[ "$output" != *'if ($host = "a.example.com") {'* ]]
  [[ "$output" == *'if ($host = "b.example.com") {'* ]]
}

@test "(http-auth:remove-domain) removing the last domain restores the plain block" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:remove-domain "$APP" a.example.com
  run http_auth_conf "$APP"
  [[ "$output" == *'auth_basic           "Restricted";'* ]]
  [[ "$output" != *'dokku_auth_realm'* ]]
}

@test "(http-auth:remove-domain) on a disabled app does not resurrect the config" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:disable "$APP"
  run dokku http-auth:remove-domain "$APP" a.example.com
  [ "$status" -eq 0 ]
  assert_disabled "$APP"
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
}

@test "(http-auth:set-domains) with no domains on a disabled app does not resurrect the config" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:disable "$APP"
  run dokku http-auth:set-domains "$APP"
  [ "$status" -eq 0 ]
  assert_disabled "$APP"
  $SUDO test ! -f "$(http_auth_conf_path "$APP")"
}

@test "(http-auth:remove-domain) fails when the domain is missing" {
  run dokku http-auth:remove-domain "$APP"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing domain"* ]]
}

@test "(http-auth:report) --http-auth-domains lists domains" {
  dokku http-auth:add-domain "$APP" a.example.com
  dokku http-auth:add-domain "$APP" b.example.com
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$status" -eq 0 ]
  [ "$output" = "a.example.com b.example.com" ]
}

@test "(http-auth:report) --http-auth-domains is empty but successful with no domains" {
  run dokku http-auth:report "$APP" --http-auth-domains
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
