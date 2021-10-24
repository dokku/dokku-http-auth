# dokku-http-auth

dokku-http-auth is a plugin for [dokku][dokku] that gives the ability to enable or disable HTTP authentication for an application.

## Requirements

`mkpasswd` from the `whois` package is required to generate secure hash (SHA-512) from provided passwords. It will be installed via `apt-get` when calling `dokku plugins-install`.

## Installation

```sh
# dokku 0.4+
$ dokku plugin:install https://github.com/dokku/dokku-http-auth.git
```

## Commands

```
$ dokku http-auth:help
    http-auth <app>                            Display the current HTTP auth status of app
    http-auth:add-user <app> <user> <password> Add basic auth user to app
    http-auth:off <app>                        Disable HTTP auth for app
    http-auth:on <app> <user> <password>       Enable HTTP auth for app
    http-auth:remove-user <app> <user>         Remove basic auth user from app
    http-auth:report [<app>] [<flag>]          Displays an http-auth report for one or more apps
    http-auth:show-config <app>                Display app http-auth config
```

## Usage

Check HTTP auth status of my-app
```
# dokku http-auth:report my-app            # Server side
$ ssh dokku@server http-auth:report my-app # Client side

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

[dokku]: https://github.com/dokku/dokku
