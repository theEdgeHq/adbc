# Edge ADBC native releases

This fork retains upstream's `elixir_make`/`CCPrecompiler` distribution mechanism.
Its release URL points to `theEdgeHq/adbc`, and its distinct version prevents reuse
of an upstream binary containing the cancellation race.

1. Set the fork version in `mix.exs` and push an annotated `v<version>` tag.
2. The precompile workflow builds Linux GNU x64/ARM64, macOS x64/ARM64, and
   Windows x64 archives with the driver manager and other required native files.
   It checks each archive on its native platform with source compilation blocked,
   including the query and IPC cancellation regressions. Publication waits for all
   checks to pass.
3. Download `checksum.exs` from that release and commit it without changing native
   sources. Consumers pin this checksum-bearing commit. The release tag identifies
   the native source; the later commit adds only its verified checksum manifest.
4. Dispatch `precompile` with `consumer_only=true` on the checksum-bearing commit.
   This downloads the published binary into an empty cache on Electra's OTP 28
   runtime, blocks source compilation, and runs the suite plus DuckDB 2.0.0 query
   and IPC cancellation probes. Verify the local developer platform too, then
   update the consumer pin.

Archives target NIF ABI 2.17 (OTP 26 or newer). Linux builds use Ubuntu 22.04;
consumers need compatible glibc and C++ runtime libraries. musl is not included.
Missing targets or download failures retain upstream's source-build fallback,
which requires a C++ compiler, Make, and CMake. `ADBC_BUILD=true` explicitly forces
a source build for development and source-build CI.

Keep release assets unchanged after publishing. Checksums committed in the pinned
source are the consumer's integrity boundary. Both binary download and source
compilation happen at application build time, not when a deployed release starts.
