#!/usr/bin/env bats
# Unit-tests fn-http-auth-valid-address directly, since the address forms nginx
# accepts are wider than the ones the command tests exercise end to end.

load 'test_helper'

@test "(fn-http-auth-valid-address) accepts the address forms nginx allows" {
  local -a addresses=(
    127.0.0.1
    10.0.0.0/8
    0.0.0.0/0
    255.255.255.255
    ::1
    ::
    2001:db8::1
    2001:db8::/32
    2001:0db8:0000:0000:0000:0000:0000:0001
    unix:
    all
  )

  local address
  for address in "${addresses[@]}"; do
    if ! http_auth_internal fn-http-auth-valid-address "$address"; then
      echo "expected '$address' to be accepted"
      return 1
    fi
  done
}

@test "(fn-http-auth-valid-address) rejects malformed addresses" {
  local -a addresses=(
    ""
    10.0.0.256
    10.0.0
    10.0.0.1.1
    1.2.3.4/33
    1.2.3.4/
    1.2.3.4/x
    "10.0.0.1;"
    "10.0.0.1 10.0.0.2"
    not-an-ip
    2001:db8::1::2
    :1:2
    "2001:db8:"
    2001:db8::/129
    2001:db8::/x
  )

  local address
  for address in "${addresses[@]}"; do
    if http_auth_internal fn-http-auth-valid-address "$address"; then
      echo "expected '$address' to be rejected"
      return 1
    fi
  done
}
