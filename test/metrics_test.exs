defmodule Metrics.MetricsTest do
  use ExUnit.Case, async: true

  alias Metrics.Meter

  defmodule MeterMetrics do
    use Metrics, otp_app: :metrics

    def child_spec(_opts) do
      [
        meter(:requests, every: {0.25, :seconds}),
      ]
    end

    def memory(state) do
      {:ok, :erlang.memory()[:system], state}
    end
  end

  defmodule GaugeMetrics do
    use Metrics, otp_app: :metrics

    def child_spec(_opts) do
      [
        gauge(:memory,   every: {0.1, :seconds}),
      ]
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

      assert_receive {:metric, :meter, :requests, 3, {0.25, :seconds}}
      assert_receive {:metric, :meter, :requests, 0, {0.25, :seconds}}, 500
    end
  end

  describe "gauges" do
    test "keeps number of marks within interval, then resets" do
      {:ok, _metrics} = GaugeMetrics.start_link()
      Metrics.register(GaugeMetrics, :memory)

      assert_receive {:metric, :gauge, :memory, _, {0.1, :seconds}}, 200
      assert_receive {:metric, :gauge, :memory, _, {0.1, :seconds}}, 200
    end
  end
end
