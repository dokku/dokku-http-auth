# dokku-http-auth

dokku-http-auth is a plugin for [dokku][dokku] that gives the ability to enable or disable HTTP authentication for an application.

## Requirements

`mkpasswd` from the `whois` package is required to generate secure hash (SHA-512) from provided passwords. It will be installed via `apt-get` when calling `dokku plugins-install`.

## Installation

```sh
$ sudo git clone https://github.com/Flink/dokku-http-auth.git /var/lib/dokku/plugins/http-auth
$ dokku plugins-install
```

## Commands

```
$ dokku help
    http-auth <app>                                 Display the current HTTP auth status of app
    http-auth:on <app> <user> <password>            Enable HTTP auth for app
    http-auth:off <app>                             Disable HTTP auth for app
```

## Usage

Check HTTP auth status of my-app
```
# dokku http-auth my-app            # Server side
$ ssh dokku@server http-auth my-app # Client side

-----> HTTP auth status of my-app:
       off
```

Enable HTTP auth for my-app
```
# dokku http-auth:on my-app username password            # Server side
$ ssh dokku@server http-auth:on my-app username password # Client side

-----> Enabling HTTP auth for my-app...
       done
```

Disable HTTP auth for my-app
```
# dokku http-auth:off my-app            # Server side
$ ssh dokku@server http-auth:off my-app # Client side

-----> Disabling HTTP auth for my-app...
       done
```

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/progrium/dokku
