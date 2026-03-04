# Inspector

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `inspector` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inspector, "~> 0.1.0"}
  ]
end
```

## LiveDashboard Integration

Add Inspector as a page in your Phoenix LiveDashboard:

```elixir
# router.ex
live_dashboard "/dashboard",
  additional_pages: [inspector: Inspector.Dashboard.Page]
```

Requires `phoenix_live_dashboard ~> 0.8` and `phoenix_live_view ~> 1.0` in your deps (already included as optional deps in Inspector).

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/inspector>.

