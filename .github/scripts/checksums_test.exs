ExUnit.start()

defmodule ReleaseChecksumsTest do
  use ExUnit.Case, async: true

  @script Path.join(__DIR__, "checksums.exs")
  @version "0.12.1-edge.1"

  setup do
    directory = Path.join(System.tmp_dir!(), "adbc-release-#{System.unique_integer([:positive])}")
    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)

    archives =
      for target <-
            ~w(aarch64-apple-darwin aarch64-linux-gnu x86_64-apple-darwin x86_64-linux-gnu x86_64-windows-msvc) do
        basename = "adbc-nif-2.17-#{target}-#{@version}.tar.gz"
        contents = "native archive fixture for #{target}"
        digest = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)
        path = Path.join(directory, basename)
        File.write!(path, contents)
        File.write!(path <> ".sha256", "#{digest}  #{basename}\n")
        {path, "sha256:#{digest}"}
      end

    %{directory: directory, archives: archives}
  end

  test "writes the exact verified archive checksums for consumers", context do
    assert {_, 0} = generate(context.directory)
    {manifest, []} = Code.eval_file(Path.join(context.directory, "checksum.exs"))

    assert manifest ==
             Map.new(context.archives, fn {path, hash} -> {Path.basename(path), hash} end)
  end

  test "rejects a corrupted archive without writing a manifest", context do
    [{path, _} | _] = context.archives
    File.write!(path, "corrupted")
    {output, status} = generate(context.directory)
    assert status != 0
    assert output =~ "checksum mismatch"
    refute File.exists?(Path.join(context.directory, "checksum.exs"))
  end

  test "requires every supported target before writing a manifest", context do
    [{path, _} | _] = context.archives
    File.rm!(path)
    assert {_, status} = generate(context.directory)
    assert status != 0
    refute File.exists?(Path.join(context.directory, "checksum.exs"))
  end

  defp generate(directory) do
    System.cmd(System.find_executable("elixir"), [@script, directory, @version],
      cd: directory,
      stderr_to_stdout: true
    )
  end
end
