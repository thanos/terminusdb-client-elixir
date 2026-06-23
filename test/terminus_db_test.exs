defmodule TerminusDBTest do
  use ExUnit.Case
  doctest TerminusDB

  test "greets the world" do
    assert TerminusDB.hello() == :world
  end
end
