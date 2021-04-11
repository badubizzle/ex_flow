defmodule ExFlow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      ExFlowWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: ExFlow.PubSub},
      # Start the Endpoint (http/https)
      ExFlowWeb.Endpoint
      # Start a worker by calling: ExFlow.Worker.start_link(arg)
      # {ExFlow.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options

    ExDag.Store.init()
    create_dirs()
    opts = [strategy: :one_for_one, name: ExFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Logger.info("Config changed")
    ExFlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp create_dirs() do
    priv_dir = :code.priv_dir(:ex_flow)
    dags_dir = Path.join(priv_dir, "/dags")
    File.mkdir(dags_dir)
  end
end
