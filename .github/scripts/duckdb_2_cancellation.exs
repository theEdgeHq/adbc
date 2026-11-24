arch = to_string(:erlang.system_info(:system_architecture))

platform =
  cond do
    String.contains?(arch, "apple-darwin") -> "osx-universal"
    String.starts_with?(arch, "x86_64") -> "linux-amd64"
    String.starts_with?(arch, "aarch64") -> "linux-arm64"
  end

Adbc.download_driver!(:duckdb,
  version: "2.0.0",
  url:
    "https://github.com/duckdb/duckdb/releases/download/v2.0.0/duckdb-shared-libs-#{platform}.tar.gz"
)

{:ok, driver} = Adbc.Driver.so_path(:duckdb, version: "2.0.0")
{:ok, database} = Adbc.Database.start_link(driver: driver, entrypoint: "duckdb_adbc_init")
{:ok, connection} = Adbc.Connection.start_link(database: database)

%{"version" => ["v2.0.0"]} =
  connection |> Adbc.Connection.query!("SELECT version() AS version") |> Adbc.Result.to_map()

GenServer.stop(connection)
GenServer.stop(database)

paths = Enum.flat_map(:code.get_path(), fn path -> ["-pa", List.to_string(path)] end)

for mode <- ["query", "ipc"] do
  {output, status} =
    System.cmd(
      System.find_executable("elixir"),
      paths ++ [Path.expand("../../test/support/cancel_reader.ex", __DIR__), mode],
      stderr_to_stdout: true,
      env: [
        {"ADBC_TEST_EBIN", Adbc |> :code.which() |> Path.dirname()},
        {"ADBC_CANCELLATION_DRIVER", driver}
      ]
    )

  IO.write(output)
  if status != 0, do: raise("#{mode} cancellation probe failed with #{status}")
end

IO.puts("Released ADBC binary passed query/IPC cancellation on DuckDB 2.0.0 and #{arch}")
