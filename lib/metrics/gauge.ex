defmodule Metrics.Gauge do
  use GenServer

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc false
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    group = Keyword.fetch!(opts, :group)
    {_m, _f, _a} = mfa = Keyword.fetch!(opts, :source)
    every = opts |> Keyword.fetch!(:every) |> Metrics.validate_timeframe()
    {mod, func, args} = opts[:init] || {__MODULE__, :init_private, []}

    {:ok, val, priv} = apply(mod, func, [opts | args])
    schedule_report({0, :second})

    {:ok, %{value: val,
            source: mfa,
            name: name,
            group: group,
            every: every,
            private: priv}}
  end

  @doc false
  def init_private(_opts), do: {:ok, nil, %{}}

  @doc false
  def handle_info(:report, %{} = state) do
    {:ok, value, private} = fetch_data(state)
    :ok = Metrics.Supervisor.report(state.group, :gauge, state.name, value, state.every)

    schedule_report(state.every)
    {:noreply, %{state | value: value, private: private}}
  end

  defp fetch_data(%{source: {mod, func, args}} = state) do
    apply(mod, func, [state.private | args])
  end

  defp schedule_report({count, unit}) do
    Process.send_after(self(), :report, Metrics.native_time_units({count, unit}))
  end
end
