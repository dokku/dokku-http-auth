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
    http-auth:add-user <app> <user> <password>  Add basic auth user to app
    http-auth:add-allowed-ip <app> <address>    Add allowed IP to basic auth bypass for an app
    http-auth:disable <app>                     Disable HTTP auth for app
    http-auth:enable <app> <user> <password>    Enable HTTP auth for app
    http-auth:remove-allowed-ip <app> <address> Remove allowed IP from basic auth bypass for an app
    http-auth:remove-user <app> <user>          Remove basic auth user from app
    http-auth:report [<app>] [<flag>]           Displays an http-auth report for one or more apps
    http-auth:show-config <app>                 Display app http-auth config
```

## Usage

### Enabling HTTP Auth

The `http-auth:enable` command can be used to enable HTTP Auth for an app.

```shell
dokku http-auth:enable node-js-app
```

```
-----> Enabling HTTP auth for node-js-app...
 !     Skipping user initialization
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
       Done
```

A user/password combination can also be specified when enabling HTTP Auth.

```shell
dokku http-auth:enable node-js-app username password
```

```
-----> Enabling HTTP auth for node-js-app...
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
       Done
```

### Adding users

Individual user/password combinations can be added at any point in time via the `http-auth:add-user` command. Specifying the same user twice will override the first instance of the user, even if the password is the same.

```shell
dokku http-auth:add-user node-js-app username password
```

```
-----> Adding username to basic auth list
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
```

### Removing users

A user can be removed via the `http-auth:remove-user` command. This command will always reload nginx, even if the user does not exist.

```shell
dokku http-auth:remove-user node-js-app username
```

```
-----> Removing username from basic auth list
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
```

### Limiting access to specific IP Addresses

> See the [Nginx Documentation](https://nginx.org/en/docs/stream/ngx_stream_access_module.html) for more information on how this works

Access can be allowed to only a specified set of IP Addresses, CIDR Blocks, or UNIX-domain sockets via the `http-auth:add-allowed-ip` command. This is used in conjunction with the basic auth support.

```shell
dokku http-auth:add-allowed-ip node-js-app 127.0.0.1
````

```
-----> Adding 127.0.0.1 to allowed ip list
-----> Ensuring network configuration is in sync for node-js-app
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
```

The specified IP address can be removed via the `http-auth:remove-allowed-ip` command.

```shell
dokku http-auth:remove-allowed-ip node-js-app 127.0.0.1
````

```
-----> Removing 127.0.0.1 from allowed ip list
-----> Ensuring network configuration is in sync for node-js-app
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Enabling HSTS
       Reloading nginx
```

### Viewing http auth config

The nginx `http-auth.conf` file can be viewed via the `http-auth:show-config` command. This command will _not_ output the `htaccess` file.

```shell
dokku http-auth:show-config node-js-app username
```

```
auth_basic           "Restricted";
auth_basic_user_file /etc/nginx/http-auth/node-js-app/htpasswd;
```

### Displaying http auth reports for an app

You can get a report about the app's http-auth status using the `http-auth:report` command:

```shell
# dokku http-auth:report node-js-app
```

```
=====> node-js-app http-auth information
       Http auth enabled:             true
       Http auth allowed ips:         127.0.0.1
       Http auth users:               root username
```

You can pass flags which will output only the value of the specific information you want. For example:

```shell
dokku http-auth:report node-js-app --http-auth-enabled
```

### How state is persisted

Whether HTTP auth is enabled for an app is tracked as an app property, and the generated nginx include (`nginx.conf.d/http-auth.conf`) is regenerated from that state on every deploy. This keeps the include in sync with the configured users and allowed IPs, and restores it automatically if it was ever left empty or out of date.

### Renaming, cloning, and destroying apps

Because the htpasswd file lives outside the app home directory, the plugin keeps it in sync as apps move. Renaming an app moves both the enabled/allowed-ip state and the htpasswd to the new app, cloning an app copies them, and in both cases the nginx include is re-rendered to point at the new app's htpasswd. This means a renamed or cloned app keeps working with the same credentials, with no need to disable and re-enable HTTP auth. Destroying an app removes its properties and htpasswd.

### Where the htpasswd file lives

The htpasswd file is stored at `/etc/nginx/http-auth/<app>/htpasswd`. It used to live in the app home directory (`/home/dokku/<app>/htpasswd`), but on Ubuntu 21.04 and newer `/home/dokku` is created mode `750`, which the nginx worker (running as `www-data`) cannot traverse - so reading the `auth_basic_user_file` at request time failed with a `permission denied` error and a 500. `/etc/nginx` is traversable by the worker, so the file is readable there.

The directory is owned by `root` and dokku manages it through a small helper granted access via `/etc/sudoers.d/dokku-http-auth`, which is installed when the plugin is installed. Existing installs are migrated automatically on plugin upgrade. Because the file lives under the world-traversable `/etc/nginx`, its salted SHA-512 password hashes are readable by local users on the host; the file previously relied on `/home/dokku`'s restrictive permissions for that.

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/dokku/dokku
