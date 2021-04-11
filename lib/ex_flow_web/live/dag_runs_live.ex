defmodule ExFlowWeb.DagLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAGRun
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    dags = ExDag.Store.get_dags()
    Logger.debug("DAGS: #{inspect(dags)}")
    ExFlow.Notifications.subscribe()
    cols = get_cols()
    {:ok, assign(socket, query: "", dags: dags, rows: build_rows(dags), cols: cols)}
  end

  @impl true
  def handle_event("run_dag", %{"id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.run_dag(dag)
    {:noreply, socket}
  end

  def handle_event("resume_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.resume_dag(run)
    {:noreply, socket}
  end

  def handle_event("stop_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.stop_dag(run)
    {:noreply, socket}
  end

  def handle_event("delete_dag", %{"id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.delete_dag(dag)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dag_status, _dag}, socket) do
    dags = ExDag.Store.get_dags()
    {:noreply, assign(socket, dags: dags, rows: build_rows(dags), cols: get_cols())}
  end

  @impl true
  def render(assigns) do
    Phoenix.View.render(ExFlowWeb.LiveView, "dags.html", assigns)
  end

  def get_dag_runs(dag) do
    ExDag.Store.get_dag_runs(dag)
  end

  def get_cols() do
    [
      "DAD ID",
      "Status",
      "Total Tasks",
      "Running Tasks",
      "Pending Tasks",
      "Completed Tasks",
      "Start Date"
      # "Started At",
      # "Ended At",
      # "Took",
      # "Runs",
      # "Result",
      # "Payload"
    ]
  end

  def get_dag_row_values(%DAG{} = dag) do
    {completed, pending, running} =
      Enum.reduce(dag.tasks, {0, 0, 0}, fn {_, task}, {c, p, r} ->
        cond do
          DAGTask.is_completed(task) ->
            {c + 1, p, r}

          DAGTask.is_pending(task) ->
            {c, p + 1, r}

          DAGTask.is_running(task) ->
            {c, p, r + 1}

          true ->
            {c, p, r}
        end
      end)

    [
      {:id, dag.dag_id},
      {:status, dag.status},
      {:tasks, Enum.count(dag.tasks)},
      {:running, running},
      {:pending, pending},
      {:completed, completed}
    ]
  end

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

  def build_rows(dags) do
    rows =
      Enum.map(dags, fn {_dag_id, dag} ->
        runs =
          dag
          |> ExDag.Store.get_dag_runs()
          |> Enum.map(fn {_, %DAGRun{id: run_id, dag: dag, started_at: started_at}} ->
            column_values =
              get_dag_row_values(dag)
              |> Keyword.put(:start_date, started_at)

            [
              {:cols, column_values},
              {:run_id, run_id},
              {:status, dag.status},
              {:completed, ExDag.Store.completed?(dag)},
              {:running, ExDag.Store.is_running(run_id)}
            ]
          end)

        %{runs: runs, id: dag.dag_id}
      end)

    Logger.info("Rows: #{inspect(rows)}")
    rows
  end

  def format_time(nil) do
    "-"
  end

  def format_time(d) do
    "#{d.hour}:#{d.minute}:#{d.second}"
  end
end
