# Example

An example of signaling server based on `Membrane.WebRTC.Server`.

## Configuration

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```
$ openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser. Custom ip,
port or other Plug options can be set up in `config/config.exs`. 

## Usage

Run application with

```
$ mix start
```

You can join videochat in: 
`https://YOUR-IP-ADDRESS:PORT/?room=room&username=USERNAME&password=PASSWORD`, for example 
[here](https://localhost:8443/?room=room&username=JohnSmith&password=1234). You should see video 
stream from your and every other peer cameras.

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
