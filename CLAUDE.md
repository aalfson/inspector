# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Elixir library wrapping `:recon` and `:erlang.process_info` for BEAM process inspection. Returns structured maps. Includes an optional Phoenix LiveDashboard page.

## Commands

```bash
mix deps.get          # install deps
mix compile           # compile
mix test              # run all tests
mix test test/inspector/utils_test.exs           # single test file
mix test test/inspector/utils_test.exs:42        # single test at line
mix format            # format code
mix format --check-formatted  # check formatting
```

## Architecture

```
Inspector              — public API facade, delegates to internal modules
Inspector.Utils        — PID parsing/conversion (accepts pid, tuple, string, atom)
Inspector.Process      — single-process inspection (info, mailbox, state)
Inspector.Top          — top N processes by attribute (wraps :recon.proc_count/proc_window)
Inspector.Aggregate    — function-count aggregations via Task.async_stream
Inspector.Dashboard.Page         — Phoenix LiveDashboard page (LiveView)
Inspector.Dashboard.FunctionDefs — metadata + execute dispatchers for dashboard functions
Inspector.Dashboard.Runner       — executes Inspector functions, supports remote nodes via RPC
```

- `Inspector` is a facade — all public functions delegate to `Process`, `Top`, or `Aggregate`
- All PID arguments everywhere go through `Utils.to_pid/1` which accepts multiple formats (pid, `{a,b,c}`, `"#PID<0.1.0>"`, `"<0.1.0>"`, `"0.1.0"`, registered atom)
- Dashboard modules are optional — `phoenix_live_dashboard` and `phoenix_live_view` are optional deps
- Test helpers in `test/support/test_processes.ex` (compiled only in test env via `elixirc_paths`)

## Conventions

- All public functions return `{:ok, result} | {:error, reason}` (idiomatic error tuples)
- `@moduledoc` and `@doc` on all public modules/functions
- Typespecs on all public functions
