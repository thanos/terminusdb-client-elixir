defmodule TerminusDB.PatchTest do
  use ExUnit.Case, async: true

  alias TerminusDB.Patch

  describe "from_json/1" do
    test "parses JSON string into Patch struct" do
      assert {:ok, patch} =
               Patch.from_json(
                 ~s({"name": {"@op": "SwapValue", "@before": "old", "@after": "new"}})
               )

      assert %Patch{} = patch
      assert patch.content["name"]["@after"] == "new"
    end

    test "returns error on invalid JSON" do
      assert {:error, _} = Patch.from_json("not json")
    end
  end

  describe "from_json!/1" do
    test "parses or raises" do
      patch =
        Patch.from_json!(~s({"name": {"@op": "SwapValue", "@before": "old", "@after": "new"}}))

      assert patch.content["name"]["@before"] == "old"
    end
  end

  describe "to_json/1" do
    test "serializes to JSON string" do
      patch = %Patch{
        content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}
      }

      json = Patch.to_json(patch)
      assert is_binary(json)
      assert json =~ "SwapValue"
    end
  end

  describe "update/1" do
    test "extracts after values from SwapValue" do
      patch = %Patch{
        content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}
      }

      assert Patch.update(patch) == %{"name" => "new"}
    end

    test "handles nested SwapValue" do
      patch = %Patch{
        content: %{
          "name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"},
          "address" => %{"city" => %{"@op" => "SwapValue", "@before" => "NYC", "@after" => "LA"}}
        }
      }

      assert Patch.update(patch) == %{"name" => "new", "address" => %{"city" => "LA"}}
    end
  end

  describe "before/1" do
    test "extracts before values from SwapValue" do
      patch = %Patch{
        content: %{"name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}}
      }

      assert Patch.before(patch) == %{"name" => "old"}
    end

    test "handles nested SwapValue" do
      patch = %Patch{
        content: %{
          "name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"},
          "address" => %{"city" => %{"@op" => "SwapValue", "@before" => "NYC", "@after" => "LA"}}
        }
      }

      assert Patch.before(patch) == %{"name" => "old", "address" => %{"city" => "NYC"}}
    end

    test "preserves non-SwapValue values" do
      patch = %Patch{
        content: %{
          "id" => "Person/1",
          "name" => %{"@op" => "SwapValue", "@before" => "old", "@after" => "new"}
        }
      }

      assert Patch.before(patch) == %{"id" => "Person/1", "name" => "old"}
    end

    test "handles deeply nested non-SwapValue" do
      patch = %Patch{
        content: %{
          "meta" => %{
            "created" => "2024-01-01",
            "tag" => %{"@op" => "SwapValue", "@before" => "a", "@after" => "b"}
          }
        }
      }

      result = Patch.before(patch)
      assert result["meta"]["created"] == "2024-01-01"
      assert result["meta"]["tag"] == "a"
    end
  end

  describe "copy/1" do
    test "creates a deep copy" do
      patch = %Patch{content: %{"name" => "value"}}
      copy = Patch.copy(patch)
      assert copy == patch
      assert copy.content == patch.content
    end

    test "deep copies nested maps" do
      patch = %Patch{content: %{"a" => %{"b" => %{"c" => [1, 2, 3]}}}}
      copy = Patch.copy(patch)
      assert copy.content["a"]["b"]["c"] == [1, 2, 3]
    end

    test "deep copies lists" do
      patch = %Patch{content: [%{"x" => 1}, %{"y" => 2}]}
      copy = Patch.copy(patch)
      assert copy.content == [%{"x" => 1}, %{"y" => 2}]
    end
  end

  describe "update/1 edge cases" do
    test "returns empty map when no SwapValue ops" do
      patch = %Patch{content: %{"name" => "unchanged"}}
      assert Patch.update(patch) == %{}
    end

    test "handles deep nesting" do
      patch = %Patch{
        content: %{
          "a" => %{"b" => %{"c" => %{"@op" => "SwapValue", "@before" => 1, "@after" => 2}}}
        }
      }

      assert Patch.update(patch) == %{"a" => %{"b" => %{"c" => 2}}}
    end

    test "handles list content" do
      patch = %Patch{content: [%{"@op" => "SwapValue", "@after" => "x"}]}
      assert Patch.update(patch) == %{}
    end
  end
end
