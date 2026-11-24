defmodule Adbc.CancellationTest do
  use ExUnit.Case, async: false

  # An unsafe native release aborts the entire VM, so run each regression in
  # its own OS process rather than terminating the rest of the test suite.
  for mode <- ["query", "ipc"] do
    @tag timeout: 120_000
    test "caller death during #{mode} consumption leaves the connection usable" do
      mode = unquote(mode)

      paths =
        Enum.flat_map(:code.get_path(), fn path -> ["-pa", List.to_string(path)] end)

      {output, status} =
        System.cmd(
          System.find_executable("elixir"),
          paths ++ [Path.join(__DIR__, "support/cancel_reader.ex"), mode],
          stderr_to_stdout: true,
          env: [
            {"ADBC_TEST_EBIN", Adbc |> :code.which() |> Path.dirname()},
            {"ERL_CRASH_DUMP", Path.join(System.tmp_dir!(), "adbc-cancellation.dump")}
          ]
        )

      assert status == 0, output
      assert output =~ "cancelled #{mode} readers without losing the connection"
    end
  end
end
