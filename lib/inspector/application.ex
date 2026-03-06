defmodule Inspector.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Inspector.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Inspector.Supervisor)
  end
end
