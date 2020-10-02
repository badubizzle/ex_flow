# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :ex_flow, ExFlowWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "aBD6egcjOxDKJWU5mhKFT0JNSiJfobaNow9XuFemta8h0oM+tMUo8bAg+sjz+kCm",
  render_errors: [view: ExFlowWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: ExFlow.PubSub,
  live_view: [signing_salt: "4rtCIOZf"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
