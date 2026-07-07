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
    http-auth:add-domain <app> <domain>         Restrict basic auth to the given domain (empty list = all domains)
    http-auth:disable <app>                     Disable HTTP auth for app
    http-auth:enable <app> <user> <password>    Enable HTTP auth for app
    http-auth:remove-allowed-ip <app> <address> Remove allowed IP from basic auth bypass for an app
    http-auth:remove-domain <app> <domain>      Stop restricting basic auth to the given domain
    http-auth:remove-user <app> <user>          Remove basic auth user from app
    http-auth:report [<app>] [<flag>]           Displays an http-auth report for one or more apps
    http-auth:set-domains <app> [<domain>...]   Replace the set of domains basic auth is restricted to
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

### Restricting auth to specific domains

By default HTTP auth applies to every domain attached to an app. When an app serves
multiple domains you can restrict the password prompt to a subset of them, leaving the
others public.

Add a domain to the auth list with `http-auth:add-domain`. The domain must already be
attached to the app (see `dokku domains:report`); an unattached domain is rejected. Adding
a domain enables HTTP auth for the app if it was not already enabled.

```shell
dokku http-auth:add-domain node-js-app secure.example.com
```

```
-----> Adding secure.example.com to auth domain list
-----> Configuring node-js-app.dokku.me...(using built-in template)
-----> Creating https nginx.conf
       Reloading nginx
```

While the auth domain list is non-empty, only the listed domains present the password
prompt; every other domain of the app is served without auth. When the list is empty (the
default) auth applies to all of the app's domains, exactly as before.

Remove a single domain with `http-auth:remove-domain`:

```shell
dokku http-auth:remove-domain node-js-app secure.example.com
```

Replace the entire list in one call with `http-auth:set-domains`. Passing no domains clears
the list, returning the app to app-wide auth:

```shell
# restrict auth to exactly these two domains
dokku http-auth:set-domains node-js-app secure.example.com admin.example.com

# clear the list -> auth applies to all domains again
dokku http-auth:set-domains node-js-app
```

> **Note:** allowed IPs (`http-auth:add-allowed-ip`) apply to **all** of an app's domains and
> cannot be scoped per-domain. If you combine allowed IPs with a domain restriction, a domain
> that is not in the auth list will still reject clients whose IP is not allowed (HTTP 403)
> rather than being fully public. The plugin prints a warning when the two features are combined.

### Viewing http auth config

The nginx `http-auth.conf` file can be viewed via the `http-auth:show-config` command. This command will _not_ output the `htaccess` file.

```shell
dokku http-auth:show-config node-js-app username
```

```
auth_basic           "Restricted";
auth_basic_user_file /etc/nginx/http-auth/node-js-app/htpasswd;
```

When auth is restricted to specific domains, the realm is gated on the request host instead:

```
set $dokku_auth_realm off;
if ($host = "secure.example.com") {
  set $dokku_auth_realm "Restricted";
}
auth_basic           $dokku_auth_realm;
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
       Http auth domains:             secure.example.com
       Http auth users:               root username
```

The `Http auth domains` row (and the `--http-auth-domains` flag) lists the domains auth is
restricted to; an empty value means auth applies to all of the app's domains.

You can pass flags which will output only the value of the specific information you want. For example:

```shell
dokku http-auth:report node-js-app --http-auth-enabled
```

The report can also be emitted as JSON for programmatic use by passing `--format json`:

```shell
# dokku http-auth:report node-js-app --format json
```

```json
{"enabled":"true","allowed-ips":"127.0.0.1","domains":"secure.example.com","users":"root username"}
```

All values are JSON strings, and list values (`allowed-ips`, `domains`, `users`) are space-joined, matching the human-readable rows. The `--format json` flag cannot be combined with an individual info flag. Passing `--global` reports global properties only; since http-auth has no global properties, `http-auth:report --global --format json` returns `{}`.

### How state is persisted

Whether HTTP auth is enabled for an app is tracked as an app property, and the generated nginx include (`nginx.conf.d/http-auth.conf`) is regenerated from that state on every deploy. This keeps the include in sync with the configured users and allowed IPs, and restores it automatically if it was ever left empty or out of date.

### Renaming, cloning, and destroying apps

Because the htpasswd file lives outside the app home directory, the plugin keeps it in sync as apps move. Renaming an app moves the enabled state, allowed-ip and auth-domain lists, and the htpasswd to the new app, cloning an app copies them, and in both cases the nginx include is re-rendered to point at the new app's htpasswd. This means a renamed or cloned app keeps working with the same credentials, with no need to disable and re-enable HTTP auth. Destroying an app removes its properties and htpasswd.

### Where the htpasswd file lives

The htpasswd file is stored at `/etc/nginx/http-auth/<app>/htpasswd`. It used to live in the app home directory (`/home/dokku/<app>/htpasswd`), but on Ubuntu 21.04 and newer `/home/dokku` is created mode `750`, which the nginx worker (running as `www-data`) cannot traverse - so reading the `auth_basic_user_file` at request time failed with a `permission denied` error and a 500. `/etc/nginx` is traversable by the worker, so the file is readable there.

The directory is owned by `root` and dokku manages it through a small helper granted access via `/etc/sudoers.d/dokku-http-auth`, which is installed when the plugin is installed. Existing installs are migrated automatically on plugin upgrade. Because the file lives under the world-traversable `/etc/nginx`, its salted SHA-512 password hashes are readable by local users on the host; the file previously relied on `/home/dokku`'s restrictive permissions for that.

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/dokku/dokku
