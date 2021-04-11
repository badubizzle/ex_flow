defmodule ExFlow.Utils do
  @moduledoc false
  def get_dags_dir() do
    Path.join(:code.priv_dir(:ex_flow), "/dags")
  end

  def get_dag_path(dag_id) do
    file_name = "dag_file_#{dag_id}"
    Path.join(get_dags_dir(), file_name)
  end
end
