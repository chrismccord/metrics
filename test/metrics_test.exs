defmodule Metrics.MetricsTest do
  use ExUnit.Case, async: true

  alias Metrics.Meter

  defmodule MeterMetrics do
    import Metrics

    def start_link do
      Metrics.Supervisor.start_link(__MODULE__, [
        meter(:requests, every: {250, :millisecond}),
      ], strategy: :one_for_one)
    end

    def memory(state) do
      {:ok, :erlang.memory()[:system], state}
    end
  end

  defmodule GaugeMetrics do
    import Metrics

    def start_link do
      Metrics.Supervisor.start_link(__MODULE__, [
        gauge(:memory, every: {100, :millisecond}),
      ], strategy: :one_for_one)
    end

    def memory(state) do
      {:ok, :erlang.memory()[:system], state}
    end
  end


  describe "meters" do
    test "keeps number of marks within interval, then resets" do
      {:ok, _metrics} = MeterMetrics.start_link()
      Metrics.register(MeterMetrics)
      Meter.mark(MeterMetrics, :requests)
      Meter.mark(MeterMetrics, :requests)
      Meter.mark(MeterMetrics, :requests)

      assert_receive {:metric, :meter, :requests, 3, {250, :millisecond}}
      assert_receive {:metric, :meter, :requests, 0, {250, :millisecond}}, 500
    end
  end

  describe "gauges" do
    test "keeps number of marks within interval, then resets" do
      {:ok, _metrics} = GaugeMetrics.start_link()
      Metrics.register(GaugeMetrics, :memory)

      assert_receive {:metric, :gauge, :memory, _, {100, :millisecond}}, 200
      assert_receive {:metric, :gauge, :memory, _, {100, :millisecond}}, 200
    end
  end
end
