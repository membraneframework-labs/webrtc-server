import Config

config :example,
  # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
  scheme: :https,
  port: 8443,
  ip: {0, 0, 0, 0},
  password: "PASSWORD",
  # Attach your SSL certificate and key files here
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem"
