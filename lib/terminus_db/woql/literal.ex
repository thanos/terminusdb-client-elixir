defmodule TerminusDB.WOQL.Literal do
  @moduledoc false

  # Value/literal helpers for WOQL queries.
  # These return pre-built value dicts or strings that the encoder passes
  # through or wraps in the appropriate wrapper type.

  @doc """
  Wraps a name as a WOQL variable string (`"v:Name"`).

  ## Examples

      iex> TerminusDB.WOQL.Literal.var("Person")
      "v:Person"

      iex> TerminusDB.WOQL.Literal.var("v:Person")
      "v:Person"

  """
  @spec var(String.t()) :: String.t()
  def var(name) when is_binary(name) do
    if String.starts_with?(name, "v:") do
      name
    else
      "v:#{name}"
    end
  end

  @doc """
  Wraps a string as an `xsd:string` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.Literal.string("hello")
      %{"@type" => "xsd:string", "@value" => "hello"}

  """
  @spec string(String.t()) :: map()
  def string(value) when is_binary(value) do
    %{"@type" => "xsd:string", "@value" => value}
  end

  @doc """
  Wraps a boolean as an `xsd:boolean` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.Literal.boolean(true)
      %{"@type" => "xsd:boolean", "@value" => true}

  """
  @spec boolean(boolean()) :: map()
  def boolean(value) when is_boolean(value) do
    %{"@type" => "xsd:boolean", "@value" => value}
  end

  @doc """
  Wraps a `DateTime`, `NaiveDateTime`, or ISO 8601 string as an
  `xsd:dateTime` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.Literal.datetime("2026-01-15T10:30:00Z")
      %{"@type" => "xsd:dateTime", "@value" => "2026-01-15T10:30:00Z"}

  """
  @spec datetime(DateTime.t() | NaiveDateTime.t() | String.t()) :: map()
  def datetime(%DateTime{} = dt),
    do: %{"@type" => "xsd:dateTime", "@value" => DateTime.to_iso8601(dt)}

  def datetime(%NaiveDateTime{} = dt),
    do: %{"@type" => "xsd:dateTime", "@value" => NaiveDateTime.to_iso8601(dt)}

  def datetime(value) when is_binary(value), do: %{"@type" => "xsd:dateTime", "@value" => value}

  @doc """
  Wraps a `Date` or ISO 8601 string as an `xsd:date` literal dict.

  ## Examples

      iex> TerminusDB.WOQL.Literal.date("2026-01-15")
      %{"@type" => "xsd:date", "@value" => "2026-01-15"}

  """
  @spec date(Date.t() | String.t()) :: map()
  def date(%Date{} = d), do: %{"@type" => "xsd:date", "@value" => Date.to_iso8601(d)}
  def date(value) when is_binary(value), do: %{"@type" => "xsd:date", "@value" => value}

  @doc """
  Wraps a value as a typed literal dict. The type is prefixed with `xsd:` if it
  does not already contain a colon.

  ## Examples

      iex> TerminusDB.WOQL.Literal.literal("42", "integer")
      %{"@type" => "xsd:integer", "@value" => "42"}

      iex> TerminusDB.WOQL.Literal.literal("foo", "custom:type")
      %{"@type" => "custom:type", "@value" => "foo"}

  """
  @spec literal(term(), String.t()) :: map()
  def literal(value, type) when is_binary(type) do
    prefixed = if String.contains?(type, ":"), do: type, else: "xsd:#{type}"
    %{"@type" => prefixed, "@value" => value}
  end

  @doc """
  Wraps a string as a `NodeValue` IRI — use for triple objects that should be
  treated as IRIs rather than string literals.

  ## Examples

      iex> TerminusDB.WOQL.Literal.iri("@schema:Person")
      %{"@type" => "NodeValue", "node" => "@schema:Person"}

  """
  @spec iri(String.t()) :: map()
  def iri(node) when is_binary(node) do
    %{"@type" => "NodeValue", "node" => node}
  end
end
