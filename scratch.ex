defmodule Demo.Metrics do
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
    {:ok, :memsup.get_system_memory_data(), state}
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
  def phoenix_controller_call(:stop, time_diff, :ok) do
    Metrics.Meter.mark(__MODULE__, :requests)
    :ok
  end
end
