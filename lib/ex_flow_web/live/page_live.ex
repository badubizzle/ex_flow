defmodule ExFlowWeb.PageLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAGRun
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

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
     assign(socket, query: "", results: %{}, dags: dags, rows: build_dags(dags), cols: get_cols())}
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

    {:noreply, assign(socket, dags: dags, rows: build_dags(dags), cols: get_cols())}
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

    {:noreply, assign(socket, dags: dags, rows: build_dags(dags), cols: get_cols())}
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

  @spec get_task_values(ExDag.DAG.DAGTask.t(), atom | %{task_deps: map}) :: [...]
  def get_task_values(%DAGTask{last_run: nil} = task, dag) do
    deps =
      case Map.get(dag.task_deps, task.id, []) do
        [] -> "-"
        l -> Enum.join(l, ", ")
      end

    [
      {:id, task.id},
      {:status, :pending},
      {:deps, deps},
      {:retries, task.retries},
      {:start_date, task.start_date |> format_time()},
      {:started_at, "-"},
      {:ended_at, "-"},
      {:lapse, "-"},
      {:runs, 0},
      {:result, "-"},
      {:payload, "-"}
    ]
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
      {:id, task.id},
      {:status, last_run.status},
      {:deps, deps},
      {:retries, task.retries},
      {:start_date, task.start_date |> format_time()},
      {:started_at, last_run.started_at |> format_time()},
      {:ended_at, last_run.ended_at |> format_time()},
      {:lapse, "#{lapse}s"},
      {:runs, DAG.get_runs(dag, task.id) |> Enum.count()},
      {:result, last_run.result || last_run.error},
      {:payload, "#{inspect(last_run.payload)}"}
    ]
  end

  def build_dags(dags) do
    Logger.info("Building dags: #{inspect(dags)}")

    result =
      dags
      |> Enum.map(fn {_, dag} ->
        tasks =
          Enum.map(dag.tasks, fn {_, task} ->
            get_task_values(task, dag)
          end)

        %{tasks: tasks, id: dag.dag_id}
      end)

    Logger.info("Result: #{inspect(result)}")
    result
  end

  def format_time(nil) do
    "-"
  end

  def format_time(d) do
    "#{d.hour}:#{d.minute}:#{d.second}"
  end
end
