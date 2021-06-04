defmodule ExFlowWeb.PageLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAGRun

  alias ExFlow.LiveUtils

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    ExFlow.Notifications.subscribe()

    dags =
      DAG.DAGSupervisor.running_dags()
      |> Enum.map(fn
        %DAG{} = dag ->
          {dag.dag_id, dag}

        %ExDag.DAGRun{dag: dag} ->
          {dag.dag_id, dag}
      end)
      |> Map.new()

    {:ok,
     assign(socket, query: "", results: %{}, dags: dags, rows: LiveUtils.build_dags(dags), cols: LiveUtils.get_cols())}
  end

  @impl true
  def handle_event("add_dag", %{"id" => dag_id}, socket) do
    ExFlow.DAGManager.build_dag(dag_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dag_status, %DAG{} = dag}, socket) do
    Logger.info("Updating dag status 2: #{dag.dag_id} #{__MODULE__}")

    dags =
      DAG.DAGSupervisor.running_dags()
      |> Enum.map(fn
        %DAG{} = dag ->
          {dag.dag_id, dag}

        %ExDag.DAGRun{dag: dag} ->
          {dag.dag_id, dag}
      end)
      |> Map.new()

    {:noreply, assign(socket, dags: dags, rows: LiveUtils.build_dags(dags))}
  end

  def handle_info({:dag_status, %DAGRun{} = dag}, socket) do
    Logger.info("Updating dag status 2: #{dag.id} #{__MODULE__}")

    dags =
      DAG.DAGSupervisor.running_dags()
      |> Enum.map(fn
        %DAG{} = dag ->
          {dag.dag_id, dag}

        %DAGRun{dag: dag} ->
          {dag.dag_id, dag}
      end)
      |> Map.new()

    {:noreply, assign(socket, dags: dags, rows: LiveUtils.build_dags(dags))}
  end
end
