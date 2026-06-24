defmodule TerminusDB.Client.Params do
  @moduledoc false

  # Internal helpers for building Req query-parameter keyword lists.
  #
  # There are two kinds of boolean-style query parameters in the TerminusDB API:
  #
  #   * Flag parameters -- their absence on the wire means `false`. Use
  #     `flag_param/2`, which omits `false` and `nil` so we don't clutter the
  #     query string with `=false` for defaults. Examples: `full_replace`,
  #     `raw_json`, `nuke`, `create`, `force`.
  #
  #   * Tri-state parameters -- the server defaults them to `true`, and `false`
  #     is a meaningful override that MUST be sent. Use `bool_param/2`, which
  #     sends any non-nil value (including `false`). Examples: `unfold`,
  #     `minimized`, `compress_ids`, `as_list`, `branches`, `verbose`,
  #     `expand_abstract`.

  @doc """
  Returns a single-element keyword list for a flag parameter, or `[]` when the
  value is falsy (`nil` or `false`). Use for parameters whose absence means
  `false` server-side.
  """
  @spec flag_param(atom(), term()) :: keyword()
  def flag_param(_name, nil), do: []
  def flag_param(_name, false), do: []
  def flag_param(name, true), do: [{name, true}]
  def flag_param(name, value), do: [{name, value}]

  @doc """
  Returns a single-element keyword list for a tri-state boolean parameter, or
  `[]` only when the value is `nil`. Use for parameters the server defaults to
  `true`, where an explicit `false` must be sent to override the default.
  """
  @spec bool_param(atom(), term()) :: keyword()
  def bool_param(_name, nil), do: []
  def bool_param(name, value), do: [{name, value}]

  @doc """
  Concatenates a list of `{name, value}` pairs (or `[]`s) into a single keyword
  list, dropping nil/false entries according to `flag_param/2` semantics.
  """
  @spec flags([{atom(), term()} | []]) :: keyword()
  def flags(pairs) do
    Enum.flat_map(pairs, fn
      [] -> []
      {name, value} -> flag_param(name, value)
    end)
  end
end
