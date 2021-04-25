defmodule ExFlowWeb.DagRunLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  require Logger

  @impl true
  def mount(%{"dag_id" => dag_id, "run_id" => run_id} = params, _session, socket) do
    {:ok, dag_run} = ExDag.Store.get_dag_run(dag_id, run_id)
    Logger.debug("Params: #{inspect(params)}")
    ExFlow.Notifications.subscribe()
    {:ok, assign(socket, dag_run: dag_run)}
  end

  @impl true
  def handle_params(%{"dag_id" => dag_id, "run_id" => run_id} = _params, _uri, socket) do
    {:ok, %ExDag.DAGRun{} = dag_run} = ExDag.Store.get_dag_run(dag_id, run_id)
    tasks = ExDag.DAG.sorted_tasks(dag_run.dag)
    deps = ExDag.DAG.get_deps_map(dag_run.dag)

    {:noreply,
     assign(socket, run_id: dag_run.id, dag_run: dag_run, tasks: tasks, task_deps: deps)}
  end

  @impl true
  def handle_info({:dag_status, %ExDag.DAGRun{} = dag_run}, socket) do
    run_id = socket.assigns[:run_id]

    if dag_run.id == run_id do
      tasks = ExDag.DAG.sorted_tasks(dag_run.dag)
      {:noreply, assign(socket, dag_run: dag_run, tasks: tasks)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "get-task-info",
        %{"dag_id" => dag_id, "run_id" => run_id, "task_id" => task_id} = data,
        socket
      ) do
    {:ok, dag_run} = ExDag.Store.get_dag_run(dag_id, run_id)
    tasks = ExDag.DAG.sorted_tasks(dag_run.dag)
    task = Map.get(tasks, task_id)
    task_runs = Map.get(dag_run.dag.task_runs, task_id)

    assigns = %{
      task_id: task_id,
      dag_id: dag_id,
      run_id: run_id,
      task: task,
      runs: task_runs,
      dag_run: dag_run,
      deps: Map.get(dag_run.dag.task_deps, task_id, [])
    }

    html = Phoenix.View.render_to_string(ExFlowWeb.LiveView, "dag_task_status.html", assigns)
    {:reply, %{data: data, task: task, runs: task_runs, html: html}, socket}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(ExFlowWeb.LiveView, "dag_run.html", assigns)
  end
end
