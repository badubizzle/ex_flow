defmodule ExFlow.DAGManager do

  alias ExDag.DAG
  alias ExDag.DAG.DAGTask
  alias ExDag.DAG.DAGTaskRun

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

  def on_completed(state, task, result) do
    topic = "dags_listener"
    Phoenix.PubSub.broadcast(ExFlow.PubSub, topic, {:update_task_status, state})
  end

  def build_dag(dag_id) when is_binary(dag_id) do
    callback = &task_callback/2

    start_date = DateTime.utc_now() |> DateTime.add(5, :second)
    on_task_completed = &on_completed/3
    on_dag_completed = fn d ->
      on_completed(d, nil, nil)
    end
    dag =
      DAG.new(dag_id, on_task_completed, on_dag_completed)
      |> DAG.add_task!(id: :a, callback: callback, data: {:op, :+})
      |> DAG.add_task!(id: :b, callback: callback, data: {:value, 2}, parent: :a)
      |> DAG.add_task!(id: :c, callback: callback, data: {:op, :+}, parent: :a)
      |> DAG.add_task!(id: :d, callback: callback, data: {:op, :+}, parent: :c)
      |> DAG.add_task!(id: :e, callback: callback, data: {:op, :+}, parent: :c)
      |> DAG.add_task!(id: :f, callback: callback, data: {:value, 6}, parent: :d)
      |> DAG.add_task!(id: :g, callback: callback, data: {:value, 5}, start_date: start_date, parent: :d)
      |> DAG.add_task!(id: :h, callback: callback, data: {:value, 4}, parent: :e)
      |> DAG.add_task!(id: :i, callback: callback, data: {:value, 3}, parent: :e)
    dag

    r = ExDag.DAG.DAGSupervisor.run_dag(dag)

    Phoenix.Tracker.track(ExDag.Tracker, self(), "dags", "#{dag.dag_id}", %{})
    Phoenix.PubSub.subscribe(ExDag.PubSub, "dags")

    IO.inspect(r)
    dag

    on_completed(dag, nil, nil)
    dag

  end

end
