defmodule ExFlow.Notifications do

  @dag_listeners "dag_listeners"
  @dags_topic "dags"

  def broadcast(topic, data) do
    :ok = Phoenix.PubSub.broadcast(ExFlow.PubSub, topic, data)
  end

  def emit_dag_status(dag_run) do
    topic = @dag_listeners
    event = :dag_status
    broadcast(topic, {event, dag_run})
    broadcast(@dags_topic, {event, dag_run})
  end

  def subscribe(topic) do
    :ok = Phoenix.PubSub.subscribe(ExFlow.PubSub, topic)
  end

  def subscribe() do
    :ok = Phoenix.PubSub.subscribe(ExFlow.PubSub, @dags_topic)
    :ok = Phoenix.PubSub.subscribe(ExFlow.PubSub, @dag_listeners)
  end

end
