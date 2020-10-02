defmodule ExFlowWeb.PageLiveTest do
  use ExFlowWeb.ConnCase

  import Phoenix.LiveViewTest

  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "DAG"
    assert render(page_live) =~ "DAG"
  end
end
