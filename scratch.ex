defmodule MetricsDemo.Metrics do
  import Metrics

  def start_link do
    Metrics.Supervisor.start_link(__MODULE__, [
      gauge(:memory,    every: {1, :second}),
      gauge(:cpu,       every: {1, :second}),
      gauge(:processes, every: {1, :second}),
      meter(:requests,  every: {1, :second}),
    ], strategy: :one_for_one)
  end

  ## Gauges

  def memory(state) do
    mem = :memsup.get_system_memory_data()
    value = Enum.into(mem, %{
      usage: (1 - (mem[:free_memory] / mem[:total_memory])) * 100
    })
    {:ok, value, state}
  end

  def processes(state) do
    count = :erlang.system_info(:process_count)
    limit = :erlang.system_info(:process_limit)
    value = %{count: count, limit: limit, usage: (count / limit) * 100}
    {:ok, value, state}
  end

  def cpu(state) do
    {:ok, %{usage: :cpu_sup.util()}, state}
  end

  ## Instrumenters

  def phoenix_controller_call(:start, _compile, _runtime), do: :ok
  def phoenix_controller_call(:stop, _time_diff, :ok) do
    Metrics.Meter.mark(__MODULE__, :requests)
    :ok
  end
end


defmodule DemoWeb.MetricChannel do
  use MetricsDemoWeb, :channel

  def join("metric:" <> _, _params, socket) do
    Metrics.register(Demo.Metrics)
    {:ok, socket}
  end

  def handle_info({:metric, :gauge, name, value, _timeframe}, socket) do
    push socket, "gauge", %{name: name, value: value}
    {:noreply, socket}
  end
  def handle_info({:metric, :meter, name, value, {count, unit}}, socket) do
    push socket, "meter", %{
      name: name,
      value: value,
      duration: %{count: count, unit: unit}
    }
    {:noreply, socket}
  end
end

