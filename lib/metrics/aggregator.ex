defmodule Metrics.Aggregator do
  @moduledoc false
  use Supervisor

  @metric_types [:gauge, :meter]

  def start_link(mod, otp_app) do
    name = Module.concat(mod, "Aggregator")
    Supervisor.start_link(__MODULE__, [mod, name, otp_app], name: name)
  end

  def init([mod, _name, otp_app]) do
    create_table(mod)
    opts = Application.get_env(otp_app, mod) || []
    registry = registry_name(mod)

    children = [
      supervisor(Registry, [:duplicate, registry]),
      # worker(Aggregator.Server, [mod, registry]),
    ] ++ mod.child_spec(opts)

    supervise children, strategy: :one_for_one
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
