defmodule ExFlow.LiveUtils do
  alias ExDag.DAG
  alias ExDag.DAGRun
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

  require Logger

  @moduledoc false
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
    rows
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
