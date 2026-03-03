# Inspector Library - Implementation Plan

## Overview

Elixir library wrapping `:recon` and `:erlang.process_info` for convenient BEAM process inspection. Returns structured maps suitable for display in IEx or HTML (Phoenix LiveDashboard).

---

## Module Architecture

```
Inspector                  # public API facade, delegates to internal modules
Inspector.Utils            # PID parsing/conversion utilities
Inspector.Process          # single-process inspection (info, mailbox, state)
Inspector.Top              # top N processes by attribute (proc_count/proc_window)
Inspector.Aggregate        # function-count aggregations across process lists
```

All public modules and functions include `@moduledoc` and `@doc` documentation.

---

## Phase 1: PID Utilities (`Inspector.Utils`)

Convert diverse PID representations to actual `pid()` values. All public functions that accept a PID argument pipe through these converters.

### Accepted input formats

| Format | Example |
|---|---|
| `pid()` | `#PID<0.570.0>` |
| `{a, b, c}` tuple | `{0, 570, 0}` |
| `"#PID<0.570.0>"` string | |
| `"<0.570.0>"` string | |
| `"0.570.0"` string | bare dot-separated (common in log copy-paste) |
| atom | `:my_server` — resolved via `Process.whereis/1` |

### Functions

```elixir
Utils.to_pid(input) :: pid()
# Raises ArgumentError on invalid input

Utils.safe_to_pid(input) :: {:ok, pid()} | {:error, String.t()}
# Returns ok/error tuple
```

Implementation: use `:erlang.list_to_pid/1` for string conversion (expects charlist `'<0.570.0>'`), `:c.pid/3` for tuple conversion, `Process.whereis/1` for atoms.

---

## Phase 2: Single Process Inspection (`Inspector.Process`)

### `Inspector.process_info(pid_input)`

Wraps `:recon.info/1`. Returns a map with categorized info:

```elixir
%{
  meta: %{registered_name: ..., status: ..., group_leader: ..., dictionary: ...},
  signals: %{links: [...], monitors: [...], monitored_by: [...], trap_exit: ...},
  location: %{initial_call: {M, F, A}, current_stacktrace: [...]},
  memory_used: %{memory: ..., message_queue_len: ..., heap_size: ..., total_heap_size: ..., garbage_collection: ...},
  work: %{reductions: ...}
}
```

Returns `{:error, :not_found}` if process is dead.

### `Inspector.mailbox(pid_input, opts \\ [])`

Wraps `:erlang.process_info(pid, :messages)` with safety limit.

**Options:**
- `:limit` — max messages to return (default: `100`)
- `:force` — bypass hard cap check (default: `false`)

Returns:

```elixir
%{
  total: 5432,
  returned: 100,
  truncated: true,
  messages: [...]
}
```

Uses `:message_queue_len` first to check size. If queue > 1,000 and `force: false`, returns `{:error, :mailbox_too_large}`. Otherwise fetches messages and returns first `limit` via `Enum.take/2`.

**Safety consideration:** calling `:erlang.process_info(pid, :messages)` copies the entire mailbox into the caller's heap. We mitigate by:
1. Checking `:message_queue_len` first — error if > 1,000 (hard cap) unless `force: true`.
2. Returning only the first N messages.

### `Inspector.state(pid_input, opts \\ [])`

Wraps `:recon.get_state/2`.

**Options:**
- `:timeout` — ms, default `10_000`

Returns the raw process state or `{:error, reason}`.

---

## Phase 3: Top N Processes (`Inspector.Top`)

### Convenience functions (absolute snapshot via `:recon.proc_count/2`)

All default to `n = 10`.

```elixir
Inspector.top_memory(n \\ 10)
Inspector.top_reductions(n \\ 10)
Inspector.top_message_queue(n \\ 10)
Inspector.top_total_heap(n \\ 10)
Inspector.top_heap(n \\ 10)
Inspector.top_stack(n \\ 10)
```

### With time window (via `:recon.proc_window/3`)

Same functions accept a `:window` option (milliseconds):

```elixir
Inspector.top_memory(10, window: 5000)
```

When `:window` is present, delegates to `:recon.proc_window/3` instead.

### Generic function

```elixir
Inspector.top(attribute, n \\ 10, opts \\ [])
```

The named functions delegate to this.

### Return format

List of maps, sorted descending by value:

```elixir
[
  %{
    pid: #PID<0.123.0>,
    value: 45678,
    name: :my_server,          # registered name or nil
    initial_call: {M, F, A},
    current_function: {M, F, A}
  },
  ...
]
```

---

## Phase 4: Aggregate Statistics (`Inspector.Aggregate`)

Both functions accept a list of pids (in any accepted format). Uses `Task.async_stream` for parallel info fetching.

### `Inspector.current_functions(pids)`

Groups processes by `:current_function`, counts occurrences, returns descending by count.

```elixir
[
  %{function: {:gen_server, :loop, 7}, count: 142},
  %{function: {:prim_inet, :recv0, 3}, count: 37},
  ...
]
```

Implementation: uses `Task.async_stream` to call `:erlang.process_info(pid, :current_function)` in parallel, groups with `Enum.frequencies_by/2`, sorts descending.

### `Inspector.initial_calls(pids)`

Same shape, grouping by `:initial_call`.

```elixir
[
  %{function: {:supervisor, :supervisor, 1}, count: 23},
  ...
]
```

**Note:** Dead pids in the list are silently skipped.

---

## Phase 5: Test Suite

### Test strategy

BEAM inspection requires live processes. Tests will:
1. Spawn controlled processes (GenServers, bare processes) with known state
2. Assert on structured return values
3. Test error cases (dead pids, invalid input)
4. Test PID conversion edge cases

### Test files

```
test/
  inspector/
    utils_test.exs
    process_test.exs
    top_test.exs
    aggregate_test.exs
  inspector_test.exs          # integration / smoke tests for the facade
  test_helper.exs
```

### Key test scenarios

**Utils:**
- Convert pid passthrough
- Convert `{0, 1, 0}` tuple
- Convert `"#PID<0.1.0>"` string
- Convert `"<0.1.0>"` string
- Convert `"0.1.0"` bare string
- Convert registered atom name
- Atom name not registered returns error
- Invalid input raises ArgumentError
- safe_to_pid returns error tuple on invalid input

**Process:**
- process_info returns map with expected keys for a live GenServer
- process_info returns error for dead pid
- mailbox returns messages from process with known mailbox contents
- mailbox respects :limit option
- mailbox returns truncated: true when messages exceed limit
- mailbox errors on queue > 1,000 without :force
- mailbox succeeds on large queue with `force: true`
- state returns GenServer state
- state respects custom timeout
- state returns error for non-OTP process

**Top:**
- top_memory returns list of maps with expected shape
- results sorted descending by value
- top with window option returns delta-based results
- n parameter limits result count
- all 6 attribute functions delegate correctly

**Aggregate:**
- current_functions groups and counts correctly with spawned processes
- initial_calls groups and counts correctly
- dead pids in list are skipped
- accepts mixed PID formats in list
- results sorted descending by count

### Test helpers

`test/support/test_processes.ex` — helpers to spawn processes with:
- Known GenServer state
- Loaded mailbox (send N messages)
- Specific initial_call / current_function

---

## Phase 6: LiveDashboard Integration (future, out of scope for now)

Custom page in Phoenix LiveDashboard. Planned separately after core library is solid.

---

## File Structure

```
lib/
  inspector.ex                 # public API facade
  inspector/
    utils.ex                   # PID conversion
    process.ex                 # single process inspection
    top.ex                     # top N by attribute
    aggregate.ex               # function count aggregations
test/
  support/
    test_processes.ex          # test helpers for spawning controlled processes
  inspector/
    utils_test.exs
    process_test.exs
    top_test.exs
    aggregate_test.exs
  inspector_test.exs           # facade integration tests
  test_helper.exs
```

---

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Return format | Maps | Easier to pattern match, display in IEx, render in templates |
| Mailbox default limit | 100 | Safe default; large enough to be useful |
| Mailbox hard cap | 1,000 | Error + require `force: true` to bypass |
| State timeout | 10s | Per requirement; recon default (5s) too aggressive for loaded systems |
| Error handling | `{:error, reason}` | Idiomatic Elixir; don't raise on expected failures |
| PID input | All formats accepted everywhere via Utils | Single conversion layer; DRY |
| Top N default | 10 | Sensible default for all `top_*` functions |
| Aggregate parallelism | `Task.async_stream` | Parallel info fetching for large pid lists |
| Name resolution | Atoms resolved via `Process.whereis/1` | Convenience for registered processes |
| Documentation | `@moduledoc` + `@doc` on all public modules/functions | Usability and hex docs |

---

## Implementation TODO

- [ ] **Phase 1: Utils**
  - [ ] Create `lib/inspector/utils.ex` with `to_pid/1`, `safe_to_pid/1`
  - [ ] Handle all 6 input formats (pid, tuple, "#PID<...>", "<...>", "0.570.0", atom)
  - [ ] `@moduledoc` and `@doc` on all public functions
  - [ ] Create `test/inspector/utils_test.exs`

- [ ] **Phase 2: Process inspection**
  - [ ] Create `lib/inspector/process.ex`
  - [ ] Implement `info/1` — wraps `:recon.info`, returns categorized map
  - [ ] Implement `mailbox/2` — safe mailbox fetch with limit + 1k hard cap
  - [ ] Implement `state/2` — wraps `:recon.get_state` with 10s default timeout
  - [ ] `@moduledoc` and `@doc` on all public functions
  - [ ] Create `test/support/test_processes.ex` helpers
  - [ ] Create `test/inspector/process_test.exs`

- [ ] **Phase 3: Top N**
  - [ ] Create `lib/inspector/top.ex`
  - [ ] Implement `top/3` — generic, delegates to proc_count or proc_window
  - [ ] Transform recon 3-tuples into maps
  - [ ] `@moduledoc` and `@doc` on all public functions
  - [ ] Create `test/inspector/top_test.exs`

- [ ] **Phase 4: Aggregates**
  - [ ] Create `lib/inspector/aggregate.ex`
  - [ ] Implement `current_functions/1` — parallel fetch, group, count, sort desc
  - [ ] Implement `initial_calls/1` — parallel fetch, group, count, sort desc
  - [ ] `@moduledoc` and `@doc` on all public functions
  - [ ] Create `test/inspector/aggregate_test.exs`

- [ ] **Phase 5: Public API facade**
  - [ ] Rewrite `lib/inspector.ex` — expose all public functions
  - [ ] `process_info/1`, `mailbox/2`, `state/2`
  - [ ] `top_memory/1,2`, `top_reductions/1,2`, `top_message_queue/1,2`, `top_total_heap/1,2`, `top_heap/1,2`, `top_stack/1,2`, `top/3`
  - [ ] `current_functions/1`, `initial_calls/1`
  - [ ] `@moduledoc` and `@doc` on all public functions
  - [ ] Create `test/inspector_test.exs` integration tests

- [ ] **Phase 6: Polish**
  - [ ] Typespecs on all public functions
  - [ ] Verify all tests pass
  - [ ] Test in IEx manually for ergonomics
