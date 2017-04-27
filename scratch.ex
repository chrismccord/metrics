config :my_app, MyApp.Metrics,
  instrumenters: [MyApp.Metrics, ...]

defmodule MyApp.Metrics do
  use Metrics, otp_app: :my_app

  def child_spec(_opts) do
    [
      # gauges
      gauge(:memory,       every: {10, :seconds}),
      gauge(:active_users, every: {5,  :minutes}),
      gauge(:ets_tables,   every: {1,  :minutes}),
      # meters
      meter(:requests,     every: {1,  :seconds}, ave: {[1, 5, 15], :minutes}),
    ]
  end


  ## Gauges

  def memory(state) do
    {:ok, Enum.into(:erlang.memory(), %{}, state}
  end

  def ets_tables(state) do
    {:ok, length(:ets.all(), state)}
  end

  def active_users(_state) do
    import Ecto.Query
    Repo.one(from u in User, select: count(u.id),
      where: u.last_request_at >= ago(5, "minute"))
  end

  ## Instrumenters

  def phoenix_endpoint_call(:start, _compile, _runtime), do: :ok
  def phoenix_endpoint_call(:stop, time_diff, :ok) do
    # Meter
    mark(:requests, time_diff)
    :ok
  end
end
