defmodule Metrics.Supervisor do
  @moduledoc false
  use Supervisor

  @metric_types [:gauge, :meter]

  def start_link(mod, children, opts) do
    name = Module.concat(mod, "Supervisor")
    Supervisor.start_link(__MODULE__, [mod, children, opts], name: name)
  end

  def init([mod, children, opts]) do
    create_table(mod)
    registry = registry_name(mod)

    children = [
      supervisor(Registry, [:duplicate, registry]),
    ] ++ child_spec(mod, children)

    supervise children, opts
  end

  defp child_spec(mod, children) do
    Enum.map(children, fn
      {:gauge, spec} -> gauge_spec(mod, spec)
      {:meter, spec} -> meter_spec(mod, spec)
      other -> other
    end)
  end

  defp gauge_spec(mod, {name, opts}) do
    worker(Metrics.Gauge, [[
      name: name,
      group: opts[:group] || mod,
      source: opts[:source] || {mod, name, []},
      init: opts[:init],
      every: opts[:every],
    ]], id: name)
  end

  defp meter_spec(mod, {name, opts}) do
    worker(Metrics.Meter, [[
      name: name,
      group: opts[:group] || mod,
      every: opts[:every],
    ]], id: name)
  end

  def register(group) do
    group
    |> registry_name()
    |> Registry.register(:__all__, %{})
  end

  def register(group, metric_name) do
    group
    |> registry_name()
    |> Registry.register(metric_name, %{})
  end

  def report(group, type, metric_name, value, every) when type in @metric_types do
    for metric <- [metric_name, :__all__] do
      group
      |> registry_name()
      |> Registry.dispatch(metric, fn entries ->
        for {pid, _meta} <- entries do
          send(pid, {:metric, type, metric_name, value, every})
        end
      end)
    end
    :ok
  end

  def get_metric(group, metric_name) do
    group
    |> table_name()
    |> :ets.lookup_element(metric_name, 3)
  end

  def list_metrics(group) do
    group
    |> table_name()
    |> :ets.tab2list()
  end

  def report(group, metric_name, value) do
    group
    |> table_name()
    |> :ets.insert({group, metric_name, value})
    :ok
  end

  defp create_table(group) do
    group
    |> table_name()
    |> :ets.new([:set, :named_table, read_concurrency: true,
                                     write_concurrency: true])
  end

  defp table_name(group), do: :"metrics_#{group}"

  defp registry_name(group), do: :"#{group}_registry"
end
