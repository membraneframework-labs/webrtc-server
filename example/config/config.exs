import Config

config :example,
  # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
  scheme: :https,
  port: 8443,
  ip: {0, 0, 0, 0},
  password: "PASSWORD",
  # Attach your SSL certificate and key files here
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem",
  ecto_repos: [Example.Repo]

config :example, Example.Repo,
  database: "example",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: "5432"

config :example, Example.UserManager.Guardian,
  issuer: "example",
  # insert your secret_key here
  secret_key: ""
