# Example

An example of signaling server based on `Membrane.WebRTC.Server`.

## Configuration

Custom ip, port or other Plug options can be set up in `config/config.exs`. 

### Guardian

This application uses [Guardian](https://github.com/ueberauth/guardian) to authenticate 
the users. Generate your secret key with

```
$ mix guardian.gen.secret
```

and add it to the config file (`config/config.exs`). Then, migrate the users table

```
$ mix ecto.migrate
```

And finally, create one or more users

```
$ iex -S mix
iex> Example.UserManager.create_user(%{username: "username", password: "password"})
```

If you want to connect to the application outside from your local network, you need to set up 
TURN and STUN servers. Insert their URLs in `rtcConfig` in `priv/static/js/main.js`.
 
### HTTPS

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```
$ openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser.

## Usage

Run application with

```
$ mix start
```

You can join videochat in: `https://YOUR-IP-ADDRESS:PORT/`. After logging in, you should see video 
stream from your and every other peer cameras.

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
