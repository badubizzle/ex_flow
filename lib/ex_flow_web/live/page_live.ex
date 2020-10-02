defmodule ExFlowWeb.PageLive do
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

  @impl true
  def mount(_params, _session, socket) do

    dags =
      DAG.DAGSupervisor.running_dags()
      |> Enum.map(fn %DAG{}=dag ->
        {dag.dag_id, dag}
      end)
      |> Map.new()
    Phoenix.PubSub.subscribe(ExFlow.PubSub, "dags_listener")
    {:ok, assign(socket, query: "", results: %{}, dags: dags)}
  end


  @impl true
  def handle_event("add_dag", %{"id" => dag_id}, socket) do
    ExFlow.DAGManager.build_dag(dag_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_task_status, _dag}, socket) do
    dags =
      DAG.DAGSupervisor.running_dags()
      |> Enum.map(fn %DAG{}=dag ->
        {dag.dag_id, dag}
      end)
      |> Map.new()
    {:noreply, assign(socket, dags: dags )}
  end

  def handle_info(info, socket) do
    IO.inspect(info, label: "Info")
    {:noreply, socket}
  end

  def get_cols() do
    [
      "Task ID",
      "Status",
      "Depends On",
      "Retries",
      "Start Date",
      "Started At",
      "Ended At",
      "Took",
      "Runs",
      "Result",
      "Payload"
    ]
  end

  def get_task_values(%DAGTask{last_run: nil} = task, dag) do
    deps =
            case Map.get(dag.task_deps, task.id, []) do
              [] -> "-"
              l -> Enum.join(l, ", ")
            end

          [task.id, :pending, deps, task.retries, task.start_date|> format_time(), "-", "-", "-", 0, "-", "-"]

  end

  def get_task_values(%DAGTask{last_run: %DAGTaskRun{} = last_run} = task, dag) do
    lapse =
            if !is_nil(last_run.ended_at) and !is_nil(last_run.started_at) do
              DateTime.diff(last_run.ended_at, last_run.started_at)
            else
              "-"
            end

          deps =
            case Map.get(dag.task_deps, task.id, []) do
              [] -> "-"
              l -> Enum.join(l, ", ")
            end

          [
            task.id,
            last_run.status,
            deps,
            task.retries,
            task.start_date |> format_time(),
            last_run.started_at |> format_time(),
            last_run.ended_at |> format_time(),
            "#{lapse}s",
            DAG.get_runs(dag, task.id) |> Enum.count(),
            last_run.result || last_run.error,
            "#{inspect(last_run.payload)}"
          ]
  end

  def format_time(nil) do
    "-"
  end
  def format_time(d) do
    "#{d.hour}:#{d.minute}:#{d.second}"
  end
end
