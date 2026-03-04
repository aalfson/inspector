defmodule Inspector.Dashboard.Page do
  @moduledoc """
  LiveDashboard page for running Inspector functions from the browser.

  ## Usage

      # router.ex
      live_dashboard "/dashboard",
        additional_pages: [inspector: Inspector.Dashboard.Page]
  """

  use Phoenix.LiveDashboard.PageBuilder

  alias Inspector.Dashboard.{FunctionDefs, Runner}

  @impl true
  def menu_link(_, _) do
    {:ok, "Inspector"}
  end

  @impl true
  def mount(_params, _session, socket) do
    functions = FunctionDefs.all()
    grouped = FunctionDefs.grouped()
    first = List.first(functions)

    socket =
      socket
      |> assign(:nodes, nodes())
      |> assign(:selected_node, node())
      |> assign(:functions, functions)
      |> assign(:grouped, grouped)
      |> assign(:selected_function, first && first.key)
      |> assign(:func_def, first)
      |> assign(:params, %{})
      |> assign(:result, nil)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inspector-dashboard" id="inspector-dashboard">
      <script>
        // Self-installing hook for copy/download — no user config needed.
        // LiveDashboard re-mounts on page nav so we guard against double-init.
        if (!window.__inspector_hook_installed__) {
          window.__inspector_hook_installed__ = true;
          window.addEventListener("phx:inspector_copy", (e) => {
            if (e.detail && e.detail.text) {
              navigator.clipboard.writeText(e.detail.text).catch(() => {});
            }
          });
          window.addEventListener("phx:inspector_download", (e) => {
            if (e.detail && e.detail.text) {
              const blob = new Blob([e.detail.text], {type: "text/plain"});
              const url = URL.createObjectURL(blob);
              const a = document.createElement("a");
              a.href = url;
              a.download = e.detail.filename || "inspector_result.txt";
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);
              URL.revokeObjectURL(url);
            }
          });
        }
      </script>
      <style>
        .inspector-dashboard { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        .inspector-config { display: flex; flex-wrap: wrap; gap: 1rem; align-items: flex-end; margin-bottom: 1.5rem; padding: 1rem; background: #f8f9fa; border-radius: 8px; border: 1px solid #dee2e6; }
        .inspector-field { display: flex; flex-direction: column; gap: 0.25rem; }
        .inspector-field label { font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: #6c757d; }
        .inspector-field select, .inspector-field input { padding: 0.375rem 0.75rem; border: 1px solid #ced4da; border-radius: 4px; font-size: 0.875rem; }
        .inspector-desc { width: 100%; color: #6c757d; font-size: 0.8125rem; margin: 0; font-style: italic; }
        .inspector-actions { display: flex; gap: 0.5rem; align-items: flex-end; }
        .inspector-btn { padding: 0.375rem 1rem; border: none; border-radius: 4px; font-size: 0.875rem; cursor: pointer; font-weight: 500; }
        .inspector-btn-primary { background: #0d6efd; color: white; }
        .inspector-btn-primary:hover { background: #0b5ed7; }
        .inspector-btn-secondary { background: #6c757d; color: white; }
        .inspector-btn-secondary:hover { background: #5c636a; }
        .inspector-result { margin-top: 1rem; }
        .inspector-result-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5rem; }
        .inspector-result-header h3 { margin: 0; font-size: 1rem; }
        .inspector-result-actions { display: flex; gap: 0.25rem; }
        .inspector-pre { background: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 8px; overflow-x: auto; font-size: 0.8125rem; line-height: 1.5; max-height: 600px; overflow-y: auto; white-space: pre-wrap; word-break: break-all; }
        .inspector-error { background: #f8d7da; color: #842029; padding: 1rem; border-radius: 8px; border: 1px solid #f5c2c7; margin-top: 1rem; }
      </style>

      <form class="inspector-config" phx-change="form_change" phx-submit="execute">
        <div class="inspector-field">
          <label>Node</label>
          <select name="node">
            <%= for n <- @nodes do %>
              <option value={n} selected={n == @selected_node}><%= n %></option>
            <% end %>
          </select>
        </div>

        <div class="inspector-field">
          <label>Function</label>
          <select name="function">
            <%= for {group, fns} <- @grouped do %>
              <optgroup label={group_label(group)}>
                <%= for f <- fns do %>
                  <option value={f.key} selected={f.key == @selected_function}><%= f.label %></option>
                <% end %>
              </optgroup>
            <% end %>
          </select>
        </div>

        <%= if @func_def do %>
          <%= for input <- @func_def.inputs do %>
            <div class="inspector-field">
              <label><%= input.label %></label>
              <input
                type={input_type(input.type)}
                name={input.name}
                value={Map.get(@params, to_string(input.name), input.default || "")}
                placeholder={input.placeholder}
                phx-debounce="300"
              />
            </div>
          <% end %>
        <% end %>

        <div class="inspector-actions">
          <button type="submit" class="inspector-btn inspector-btn-primary">Execute</button>
          <%= if @result do %>
            <button type="button" class="inspector-btn inspector-btn-secondary" phx-click="refresh">Refresh</button>
          <% end %>
        </div>

        <%= if @func_def do %>
          <p class="inspector-desc"><%= @func_def.description %></p>
        <% end %>
      </form>

      <%= if @error do %>
        <div class="inspector-error">
          <strong>Error:</strong> <%= @error %>
        </div>
      <% end %>

      <%= if @result do %>
        <div class="inspector-result">
          <div class="inspector-result-header">
            <h3>Result</h3>
            <div class="inspector-result-actions">
              <button class="inspector-btn inspector-btn-secondary" phx-click="copy">Copy</button>
              <button class="inspector-btn inspector-btn-secondary" phx-click="download">Download</button>
            </div>
          </div>
          <pre class="inspector-pre"><%= @result %></pre>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("form_change", params, socket) do
    socket = maybe_update_node(socket, params["node"])
    {socket, function_changed?} = maybe_update_function(socket, params["function"])

    socket =
      if function_changed? do
        socket
      else
        update_params(socket, params)
      end

    {:noreply, socket}
  end

  def handle_event("execute", _, socket) do
    %{selected_function: key, selected_node: target, params: params} = socket.assigns

    socket =
      case Runner.execute(key, target, params) do
        {:ok, result} ->
          socket |> assign(:result, result) |> assign(:error, nil)

        {:error, error} ->
          socket |> assign(:error, error) |> assign(:result, nil)
      end

    {:noreply, socket}
  end

  def handle_event("refresh", _, socket) do
    handle_event("execute", %{}, socket)
  end

  def handle_event("copy", _, socket) do
    {:noreply, push_event(socket, "inspector_copy", %{text: socket.assigns.result || ""})}
  end

  def handle_event("download", _, socket) do
    key = socket.assigns.selected_function

    {:noreply,
     push_event(socket, "inspector_download", %{
       text: socket.assigns.result || "",
       filename: "inspector_#{key}.txt"
     })}
  end

  # Helpers

  defp nodes do
    [node() | Node.list()]
  end

  defp group_label(:process), do: "Process"
  defp group_label(:top), do: "Top N"
  defp group_label(:aggregate), do: "Aggregate"

  defp input_type(:number), do: "number"
  defp input_type(:text), do: "text"

  defp maybe_update_node(socket, nil), do: socket

  defp maybe_update_node(socket, node_name) do
    node_atom = String.to_existing_atom(node_name)
    allowed = [node() | Node.list()]

    if node_atom in allowed do
      assign(socket, :selected_node, node_atom)
    else
      socket
    end
  end

  defp maybe_update_function(socket, nil), do: {socket, false}

  defp maybe_update_function(socket, key_str) do
    func_def = FunctionDefs.find_by_key_string(key_str)

    cond do
      is_nil(func_def) ->
        {socket, false}

      func_def.key == socket.assigns.selected_function ->
        {socket, false}

      true ->
        socket =
          socket
          |> assign(:selected_function, func_def.key)
          |> assign(:func_def, func_def)
          |> assign(:params, %{})
          |> assign(:result, nil)
          |> assign(:error, nil)

        {socket, true}
    end
  end

  defp update_params(socket, params) do
    meta_keys = ["_target", "node", "function"]

    new_params =
      params
      |> Map.drop(meta_keys)
      |> Enum.into(socket.assigns.params)

    assign(socket, :params, new_params)
  end
end
