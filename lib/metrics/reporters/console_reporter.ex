defmodule Metrics.Reporters.ConsoleReporter do
  use GenServer

  def start_link(group, metric_names) do
    name = Module.concat(group, "ConsoleReporter")
    GenServer.start_link(__MODULE__, {group, metric_names}, name: name)
  end

  def init({group, metric_names}) do
    register(group, metric_names)
    {:ok, %{}}
  end

  def handle_info({:metric, _type, name, value, {count, unit}}, state) do
    IO.puts "#{name}: #{inspect value} / #{count} #{unit}"
    {:noreply, state}
  end

  defp register(group, []) do
    Metrics.register(group)
  end
  defp register(group, metric_names) do
    for metric <- metric_names, do: Metrics.register(group, metric)
  end
end
