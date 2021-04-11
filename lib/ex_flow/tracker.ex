defmodule ExFlow.Tracker do
  @moduledoc false

  @tracker_name ExDag.Tracker

  @spec track(topic :: binary(), key :: atom() | binary(), meta :: map()) ::
          {:ok, ref :: binary} | {:error, reason :: term}
  def track(topic, key, meta \\ %{}) do
    Phoenix.Tracker.track(@tracker_name, self(), topic, key, meta)
  end

  def track_dag(dag) do
    topic = "dags"
    key = "#{dag.dag_id}"
    track(topic, key, %{})
  end
end
