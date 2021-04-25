defmodule TaskRunComponent do
  @moduledoc false
  use Phoenix.LiveComponent

  def render(assigns) do
    t = assigns[:task]

    ~L"""
    <%= cond do %>
    <% t.status == :completed  -> %>
      <span class="task-run task-completed"><%= t.id %></span>
    <% t.status == :running  -> %>
      <span class="task-run task-running"><%= t.id %></span>
    <% true -> %>
    <span class="task-run"><%= t.id %></span>
    <% end %>
    """
  end
end

defmodule DAGRunComponent do
  @moduledoc false
  use Phoenix.LiveComponent
  alias ExFlowWeb.Router.Helpers, as: Routes

  def render(assigns) do
    run = assigns[:run]
    dag = assigns[:dag]

    ~L"""
    <tr class="">
      <%= for {_k, val} <- run[:cols] do %>
        <td><%= val %></td>
      <% end %>

      <td>
        <div style="display: inline;">
        <%= for {_k, t} <- run[:tasks] do %>
        <%= live_component @socket, TaskRunComponent, task: t %>
        <% end %>
        </div>
      </td>

    <%= cond do %>
    <% Map.get(run, :completed) == :false  and  Map.get(run, :running) == :false -> %>
    <td>
    <button
    id="resume-run-<%= Map.get(run, :run_id) %>"
    run-id="<%= Map.get(run, :run_id) %>"
    dag-id="<%= dag.id %>" phx-hook="ResumeDag" style="color: black;"> &#9654; </button>
    </td>
    <% Map.get(run, :running) == :true -> %>
      <td>
    <button
    id="stop-run-<%= Map.get(run, :run_id) %>"
    run-id="<%= run[:run_id] %>"
    dag-id="<%= dag.id %>" phx-hook="StopDag" style="color: black;">&#9612;&#9612;</button>
    </td>
    <% true  -> %>
    <% end %>
    <td>
    <%= live_patch to: Routes.live_path(@socket, ExFlowWeb.DagRunLive, dag.id, run[:run_id]) do %>
      <div class="column">
        Details
      </div>
    <% end %>
    </td>
    </tr>
    """
  end
end

defmodule ExFlowWeb.DagLive do
  @moduledoc false
  use ExFlowWeb, :live_view

  alias ExDag.DAG
  alias ExDag.DAGRun
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

  @impl true
  def mount(_params, _session, socket) do
    dags = ExDag.Store.get_dags()
    # Logger.debug("DAGS: #{inspect(dags)}")
    ExFlow.Notifications.subscribe()
    cols = get_cols()
    Process.send_after(self(), {:dag_status, nil}, 5_000)
    {:ok, assign(socket, query: "", dags: dags, rows: build_rows(dags), cols: cols)}
  end

  @impl true
  def handle_event("run_dag", %{"id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.run_dag(dag)
    dags = ExDag.Store.get_dags()
    rows = build_rows(dags)
    cols = get_cols()
    {:noreply, assign(socket, dags: dags, rows: rows, cols: cols)}
  end

  def handle_event("resume_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.resume_dag(run)
    dags = ExDag.Store.get_dags()
    rows = build_rows(dags)
    cols = get_cols()
    {:noreply, assign(socket, rows: rows, cols: cols, dags: dags)}
  end

  def handle_event("stop_dag", %{"run_id" => run_id, "dag_id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    runs = ExDag.Store.get_dag_runs(dag)
    run = Map.get(runs, run_id)
    ExFlow.DAGManager.stop_dag(run)
    dags = ExDag.Store.get_dags()
    rows = build_rows(dags)
    cols = get_cols()
    {:noreply, assign(socket, rows: rows, cols: cols, dags: dags)}
  end

  def handle_event("delete_dag", %{"id" => dag_id}, socket) do
    dags = socket.assigns.dags
    dag = Map.get(dags, dag_id)
    ExFlow.DAGManager.delete_dag(dag)
    dags = ExDag.Store.get_dags()
    rows = build_rows(dags)
    cols = get_cols()
    {:noreply, assign(socket, rows: rows, cols: cols, dags: dags)}
  end

  @impl true
  def handle_info({:dag_status, _dag}, socket) do
    # Logger.info("Updating status")
    dags = ExDag.Store.get_dags()
    rows = build_rows(dags)
    cols = get_cols()
    push_event(socket, "update_dags", %{dags: [], rows: rows, cols: cols})
    # %{rows: rows, cols: cols})}
    {:noreply, assign(socket, dags: dags, rows: rows, cols: cols)}
    # {:noreply, push_event(socket, "update_dags", %{dags: dags, rows: rows, cols: cols})}
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
      # "Total Tasks",
      # "Running Tasks",
      # "Pending Tasks",
      # "Completed Tasks",
      # "Start Date"
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
end
