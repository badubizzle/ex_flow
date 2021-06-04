

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
    <%= Phoenix.HTML.Link.link to: "/dags/#{dag.id}/runs/#{run[:run_id]}" do %>
      <div class="column">
        Details
      </div>
    <% end %>

    <%= if Map.get(run, :completed) == true  and  Map.get(run, :running) == false  do %>
    <div class="column">
      <a href="#" id="delete-dag-run-<%= run[:run_id] %>" dag-id="<%= dag.id %>" run-id="<%= run[:run_id] %>"">Delete</a>
    <% end %>
    </div>
    </td>
    </tr>
    """
  end
end
