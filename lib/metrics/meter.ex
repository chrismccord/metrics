defmodule Metrics.Meter do
  use GenServer

  def mark(group, meter_name, count \\ 1) do
    group
    |> marks_tab(meter_name)
    |> update_counter(:marks, count)
  end

  def value(group, meter_name) do
    group
    |> marks_tab(meter_name)
    |> lookup_counter(:marks)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    meter_name = Keyword.fetch!(opts, :name)
    group = Keyword.fetch!(opts, :group)
    every = opts |> Keyword.fetch!(:every) |> Metrics.validate_timeframe()
    marks_tab =
      group
      |> marks_tab(meter_name)
      |> :ets.new([:public, :named_table, read_concurrency: true])

    0 = reset_counter(marks_tab, :marks)
    schedule_report({0, :seconds})

    {:ok, %{name: meter_name,
            group: group,
            every: every,
            marks_tab: marks_tab}}
  end

  def handle_info(:report, state) do
    marks = lookup_counter(state.marks_tab, :marks)
    0 = reset_counter(state.marks_tab, :marks)
    :ok = Metrics.Aggregator.report(state.group, :meter, state.name, marks, state.every)

    schedule_report(state.every)

    {:noreply, state}
  end

  defp schedule_report({count, unit}) do
    Process.send_after(self(), :report, Metrics.native_time_units({count, unit}))
  end

  defp update_counter(tab, key, count) do
    :ets.update_counter(tab, key, {2, count}, {2, 0})
  rescue
    ArgumentError -> raise ArgumentError, "uknown counter for table #{inspect tab} and key #{inspect key}"
  end

  defp reset_counter(tab, key) do
    :ets.update_counter(tab, key, {2, 1, 0, 0}, {2, 0})
  end

  defp lookup_counter(tab, key) do
    :ets.lookup_element(tab, key, 2)
  end

  defp marks_tab(group, meter_name), do: :"#{group}_#{meter_name}"
end
