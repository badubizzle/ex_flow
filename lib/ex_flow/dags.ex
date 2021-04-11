defmodule ExFlow.DAGManager do
  @moduledoc false

  alias ExDag.DAG
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun
  require Logger

  def task_callback(task, payload) do
    wait = Enum.random(1000..2000)
    Process.sleep(wait)

    if rem(wait, 5) == 0 do
      Process.exit(self(), :kill)
    else
      case task.data do
        {:value, v} ->
          {:ok, v}

        {:op, :+} ->
          {:ok, Enum.reduce(payload, 0, fn {_k, v}, acc -> acc + v end)}

        _ ->
          IO.puts("Unhandled")
      end
    end
  end

  def run_task(task, payload) do
    task_callback(task, payload)
  end

  def build_dag(dag_id) when is_binary(dag_id) do
    start_date = DateTime.utc_now() |> DateTime.add(5, :second)

    dag =
      DAG.new(dag_id)
      |> DAG.set_handler(ExFlow.DAGHandler)
      |> DAG.set_default_task_handler(ExFlow.TaskHandler)
      |> DAG.add_task!(id: :a, data: {:op, :+})
      |> DAG.add_task!(id: :b, data: {:value, 2}, parent: :a)
      |> DAG.add_task!(id: :c, data: {:op, :+}, parent: :a)
      |> DAG.add_task!(id: :d, data: {:op, :+}, parent: :c)
      |> DAG.add_task!(id: :e, data: {:op, :+}, parent: :c)
      |> DAG.add_task!(id: :f, data: {:value, 6}, parent: :d)
      |> DAG.add_task!(id: :g, data: {:value, 5}, start_date: start_date, parent: :d)
      |> DAG.add_task!(id: :h, data: {:value, 4}, parent: :e)
      |> DAG.add_task!(id: :i, data: {:value, 3}, parent: :e)

    r = ExDag.DAG.DAGSupervisor.run_dag(dag)

    ExFlow.Tracker.track_dag(dag)
    ExFlow.Notifications.subscribe()

    Logger.debug("Run dag result: #{inspect(r)}")
    ExDag.Store.save_dag(dag)
    ExFlow.Notifications.emit_dag_status(dag)
    dag
  end

  def run_dag(dag) do
    ExDag.DAG.DAGSupervisor.run_dag(dag)
    ExFlow.Tracker.track_dag(dag)
    ExFlow.Notifications.subscribe()
    ExFlow.Notifications.emit_dag_status(dag)
  end

  def resume_dag(dag_run) do
    ExDag.DAG.DAGSupervisor.resume_dag(dag_run)
    ExFlow.Tracker.track_dag(dag_run.dag)
    ExFlow.Notifications.subscribe()
    ExFlow.Notifications.emit_dag_status(dag_run.dag)
  end

  def stop_dag(dag_run) do
    ExDag.DAG.DAGSupervisor.stop_dag(dag_run)
    ExFlow.Tracker.track_dag(dag_run.dag)
    ExFlow.Notifications.subscribe()
    ExFlow.Notifications.emit_dag_status(dag_run.dag)
  end

  def delete_dag(dag) do
    ExDag.Store.delete_dag(dag)
    ExFlow.Notifications.emit_dag_status(dag)
  end

  def create_dags_dir() do
  end
end
