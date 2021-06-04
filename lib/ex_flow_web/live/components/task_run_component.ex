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
