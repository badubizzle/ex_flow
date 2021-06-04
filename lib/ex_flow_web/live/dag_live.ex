defmodule ExFlowWeb.DagLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAGRun
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

  require Logger


  @impl true
  def mount(params, _session, socket) do
    Process.send_after(self(), {:dag_status, nil}, 5_000)
    socket = build_assigns(socket)
    {:ok, assign(socket, dag_id: Map.get(params, "dag_id"))}
  end

  def mount(%{"dag_id"=>dag_id}=params, _session, socket) do
    Process.send_after(self(), {:dag_status, nil}, 5_000)
    socket =
      socket
      |> assign(dag_id: dag_id)
      |> build_assigns()
    {:ok, assign(socket, dag_id: Map.get(params, "dag_id"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = build_assigns(socket)
    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    socket = %{
      socket
      | assigns: Map.delete(socket.assigns, :dag_id),
        changed: Map.put_new(socket.changed, :dag_id, true)
    }
    socket = build_assigns(socket) |> IO.inspect()
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_dag", %{"id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.run_dag(dag)
    socket = build_assigns(socket)
    {:noreply, socket}
  end

  def handle_event("resume_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.resume_dag(run)
    socket = build_assigns(socket)
    {:noreply, socket}
  end

  def handle_event("stop_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.stop_dag(run)
    socket = build_assigns(socket)
    {:noreply, socket}
  end

  def handle_event("delete-dag", %{"dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.delete_dag(dag)
    socket = build_assigns(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dag_status, _dag}, socket) do
    Logger.info("Updating status")
    socket = build_assigns(socket)

    push_event(socket, "update_dags", %{
      dags: [],
      rows: socket.assigns.rows,
      cols: socket.assigns.cols
    })

    {:noreply, socket}
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
      "RUN ID",
      "Status"
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
            _column_values =
              get_dag_row_values(dag)
              |> Keyword.put(:start_date, started_at)

            %{
              cols: %{dag_id: dag.dag_id, run_id: run_id},
              run_id: run_id,
              status: dag.status,
              completed: ExDag.Store.completed?(dag),
              running: ExDag.Store.is_running(run_id),
              tasks: DAG.sorted_tasks(dag)
            }
          end)

        %{runs: runs, id: dag.dag_id}
      end)

    # Logger.info("Rows: #{inspect(rows)}")
    rows
  end

  def format_time(nil) do
    "-"
  end

  def format_time(d) do
    "#{d.hour}:#{d.minute}:#{d.second}"
  end

  defp build_assigns(%{assigns: %{dag_id: dag_id}} = socket) when is_binary(dag_id) do
    {dags, rows} =
      case ExDag.Store.get_dag(dag_id) do
        {:ok, %ExDag.DAG{} = dag} ->
          rows = build_rows([{dag.dag_id, dag}])
          {[dag], rows}

        _ ->
          {[], []}
      end

    cols = get_cols()
    assign(socket, dag_id: dag_id, dags: dags, rows: rows, cols: cols)
  end

  defp build_assigns(%{assigns: _} = socket) do
    dags = ExDag.Store.get_dags()
    cols = get_cols()
    rows = build_rows(dags)
    assign(socket, dags: dags, rows: rows, cols: cols)
  end
end
