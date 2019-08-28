import Config

config :example,
  scheme: :https,
  port: 8443,
  ip: {0, 0, 0, 0},
  password: "SECRET",
  otp_app: :example,
  # Attach your SSL certificate and key files here
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem"
