defmodule Metrics do
  alias Metrics.Aggregator

  @units ~w(hours minutes seconds)a

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)
      import Supervisor.Spec

      @otp_app Keyword.fetch!(unquote(opts), :otp_app)

      def start_link do
        unquote(__MODULE__).start_link(__MODULE__, @otp_app)
      end
    end
  end

  @doc false
  def start_link(mod, otp_app) do
    Aggregator.start_link(mod, otp_app)
  end

  @doc """
  TODO
  """
  def register(group) do
    Aggregator.register(group)
  end
  def register(group, metric_name) do
    Aggregator.register(group, metric_name)
  end

  @doc """
  TODO
  """
  defmacro gauge(name, opts) do
    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).gauge_spec(__MODULE__, name, opts)
    end
  end

  @doc """
  TODO
  """
  defmacro meter(name, opts) do
    quote bind_quoted: binding(), unquote: true do
      unquote(__MODULE__).meter_spec(__MODULE__, name, opts)
    end
  end

  @doc false
  def meter_spec(mod, name, opts) do
    Supervisor.Spec.worker(Metrics.Meter, [[
      name: name,
      group: opts[:group] || mod,
      every: opts[:every],
    ]], id: name)
  end

  @doc false
  def gauge_spec(mod, name, opts) do
    Supervisor.Spec.worker(Metrics.Gauge, [[
      name: name,
      group: opts[:group] || mod,
      source: opts[:source] || {mod, name, []},
      init: opts[:init],
      every: opts[:every],
    ]], id: name)
  end

  @doc false
  def native_time_units({count, unit}) when unit in @units do
    trunc(apply(:timer, unit, [count]))
  end

  @doc false
  def validate_timeframe({val, unit} = input)
    when (is_integer(val) or is_float(val)) and unit in @units,
    do: input
  def validate_timeframe(input) do
    raise ArgumentError, """
    invalid timeframe provided for :every. Expected a 2-tuple
    with units in #{inspect @units}. For example:

        {30, :seconds}

    got: #{inspect input}
    """
  end
end
