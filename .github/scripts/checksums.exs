[directory, version] = System.argv()

targets =
  ~w(aarch64-apple-darwin aarch64-linux-gnu x86_64-apple-darwin x86_64-linux-gnu x86_64-windows-msvc)

checksums =
  Map.new(targets, fn target ->
    basename = "adbc-nif-2.17-#{target}-#{version}.tar.gz"
    archive = Path.join(directory, basename)
    [expected, ^basename] = archive |> Kernel.<>(".sha256") |> File.read!() |> String.split()
    actual = :crypto.hash(:sha256, File.read!(archive)) |> Base.encode16(case: :lower)

    if actual != expected, do: raise("checksum mismatch for #{basename}")
    {basename, "sha256:#{actual}"}
  end)

File.write!("checksum.exs", inspect(checksums, pretty: true, limit: :infinity) <> "\n")
