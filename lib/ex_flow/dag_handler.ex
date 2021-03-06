defmodule ExFlow.DAGHandler do
  @moduledoc """
  Sample implementation of daghandler behaviour
  """
  @behaviour ExDag.DAG.Handlers.DAGHandler

  @impl true
  def on_dag_completed(%ExDag.DAGRun{} = dag_run) do
    ExDag.DAG.Utils.print_status(dag_run.dag)
    ExDag.DAG.Utils.print_task_runs(dag_run.dag.task_runs)
    ExDag.Store.save_dag_run(dag_run)
    ExFlow.Notifications.emit_dag_status(dag_run)
  end

  @impl true
  def on_task_completed(%ExDag.DAGRun{} = dag_run, _task, _result) do
    ExDag.DAG.Utils.print_status(dag_run.dag)
    ExDag.DAG.Utils.print_task_runs(dag_run.dag.task_runs)
    ExDag.Store.save_dag_run(dag_run)
    ExFlow.Notifications.emit_dag_status(dag_run)
  end

  @impl true
  def on_task_started(dag_run, _task_run) do
    ExDag.DAG.Utils.print_status(dag_run.dag)
    ExDag.DAG.Utils.print_task_runs(dag_run.dag.task_runs)
    ExDag.Store.save_dag_run(dag_run)
    ExFlow.Notifications.emit_dag_status(dag_run)
  end
end
