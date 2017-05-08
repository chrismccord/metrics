defmodule Metrics do
  @moduledoc """
  TODO
  """

  @units ~w(hour minute second millisecond)a

  @doc """
  TODO
  """
  def register(group) do
    Metrics.Supervisor.register(group)
  end
  def register(group, metric_name) do
    Metrics.Supervisor.register(group, metric_name)
  end

  @doc """
  TODO
  """
  def gauge(name, opts) do
    {:gauge, {name, opts}}
  end

  @doc """
  TODO
  """
  def meter(name, opts) do
    {:meter, {name, opts}}
  end

  @doc false
  def native_time_units({count, unit}) when unit in @units do
    System.convert_time_unit(count, unit, :millisecond)
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
