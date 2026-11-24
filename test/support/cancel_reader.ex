{:ok, _} = Application.ensure_all_started(:adbc)

database_options =
  case System.get_env("ADBC_CANCELLATION_DRIVER") do
    nil -> [driver: :duckdb]
    path -> [driver: path, entrypoint: "duckdb_adbc_init"]
  end

{:ok, database} = Adbc.Database.start_link(database_options)
{:ok, connection} = Adbc.Connection.start_link(database: database)
[mode] = System.argv()
parent = self()

for iteration <- 1..100 do
  {reader, monitor} =
    spawn_monitor(fn ->
      send(parent, {:started, self()})
      sql = "SELECT i, repeat('x', 100) AS payload FROM range(1000000) t(i)"

      case mode do
        "query" ->
          Adbc.Connection.query!(connection, sql)

        "ipc" ->
          Adbc.Connection.query_pointer(connection, sql, fn stream ->
            Adbc.StreamResult.to_ipc_stream(stream)
          end)
      end
    end)

  receive do
    {:started, ^reader} -> :ok
  end

  Process.sleep(rem(iteration, 10) + 1)
  Process.exit(reader, :kill)

  receive do
    {:DOWN, ^monitor, :process, ^reader, _reason} -> :ok
  end

  %{"answer" => [42]} =
    connection
    |> Adbc.Connection.query!("SELECT 42 AS answer")
    |> Adbc.Result.to_map()
end

GenServer.stop(connection)
GenServer.stop(database)
IO.puts("cancelled #{mode} readers without losing the connection")
