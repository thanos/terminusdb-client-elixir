defmodule TerminusDB.WOQL.RDFListTest do
  use ExUnit.Case, async: true

  alias TerminusDB.WOQL
  alias TerminusDB.WOQL.RDFList

  describe "rdflist_peek/2" do
    test "builds a triple for rdf:first" do
      q = RDFList.rdflist_peek("v:List", "v:First")
      assert q.op == :triple
      assert q.args == ["v:List", "rdf:first", "v:First"]
    end

    test "encodes as Triple" do
      jsonld = WOQL.to_jsonld(RDFList.rdflist_peek("v:List", "v:First"))
      assert jsonld["@type"] == "Triple"
      assert jsonld["predicate"] == %{"@type" => "NodeValue", "node" => "rdf:first"}
    end
  end

  describe "rdflist_empty/1" do
    test "builds an eq with rdf:nil" do
      q = RDFList.rdflist_empty("v:List")
      assert q.op == :eq
      assert q.args == ["v:List", %{"@type" => "NodeValue", "node" => "rdf:nil"}]
    end

    test "encodes as Equals" do
      jsonld = WOQL.to_jsonld(RDFList.rdflist_empty("v:List"))
      assert jsonld["@type"] == "Equals"
    end
  end

  describe "rdflist_is_empty/1" do
    test "builds an eq with rdf:nil" do
      q = RDFList.rdflist_is_empty("v:List")
      assert q.op == :eq
    end
  end

  describe "rdflist_last/2" do
    test "builds an And query" do
      q = RDFList.rdflist_last("v:List", "v:Last")
      assert q.op == :and
      assert is_list(q.args)
      assert length(q.args) == 3
    end

    test "encodes as And" do
      jsonld = WOQL.to_jsonld(RDFList.rdflist_last("v:List", "v:Last"))
      assert jsonld["@type"] == "And"
    end
  end

  describe "rdflist_list/2" do
    test "builds an And query" do
      q = RDFList.rdflist_list("v:List", "v:Array")
      assert q.op == :and
      assert is_list(q.args)
    end
  end

  describe "rdflist_member/2" do
    test "builds an And query" do
      q = RDFList.rdflist_member("v:List", "v:Elem")
      assert q.op == :and
    end
  end

  describe "rdflist_nth0/3" do
    test "with index 0 returns rdf:first triple" do
      q = RDFList.rdflist_nth0("v:List", 0, "v:Elem")
      assert q.op == :triple
    end

    test "with index > 0 builds an And with nested nth" do
      q = RDFList.rdflist_nth0("v:List", 2, "v:Elem")
      assert q.op == :and
    end
  end

  describe "rdflist_nth1/3" do
    test "with index 1 returns rdf:first triple" do
      q = RDFList.rdflist_nth1("v:List", 1, "v:Elem")
      assert q.op == :triple
    end

    test "with index > 1 builds an And" do
      q = RDFList.rdflist_nth1("v:List", 3, "v:Elem")
      assert q.op == :and
    end
  end

  describe "rdflist_pop/2" do
    test "builds an And query with delete operations" do
      q = RDFList.rdflist_pop("v:List", "v:Value")
      assert q.op == :and
      ops = Enum.map(q.args, & &1.op)
      assert :delete_triple in ops
    end
  end

  describe "rdflist_push/2" do
    test "builds an And query with add operations" do
      q = RDFList.rdflist_push("v:List", "v:Value")
      assert q.op == :and
      ops = Enum.map(q.args, & &1.op)
      assert :add_triple in ops
    end
  end

  describe "rdflist_append/2" do
    test "builds an And query with add and delete operations" do
      q = RDFList.rdflist_append("v:List", "v:Value")
      assert q.op == :and
      ops = Enum.map(q.args, & &1.op)
      assert :add_triple in ops
      assert :delete_triple in ops
    end
  end

  describe "rdflist_clear/2" do
    test "builds an And query" do
      q = RDFList.rdflist_clear("v:List", "v:NewList")
      assert q.op == :and
    end
  end

  describe "rdflist_length/2" do
    test "builds an And query" do
      q = RDFList.rdflist_length("v:List", "v:Len")
      assert q.op == :and
    end
  end

  describe "rdflist_slice/4" do
    test "builds an And query" do
      q = RDFList.rdflist_slice("v:List", 0, 3, "v:Result")
      assert q.op == :and
    end
  end

  describe "rdflist_insert/3" do
    test "builds an And query with add_triple" do
      q = RDFList.rdflist_insert("v:List", 1, "v:Value")
      assert q.op == :and
      ops = Enum.map(q.args, & &1.op)
      assert :add_triple in ops
    end
  end

  describe "rdflist_drop/2" do
    test "builds an And query" do
      q = RDFList.rdflist_drop("v:List", 1)
      assert q.op == :and
    end
  end

  describe "rdflist_swap/3" do
    test "builds an And query" do
      q = RDFList.rdflist_swap("v:List", 0, 2)
      assert q.op == :and
    end
  end

  describe "unique variable generation" do
    test "localize generates unique variable names" do
      q1 = RDFList.rdflist_last("v:List", "v:Last")
      q2 = RDFList.rdflist_last("v:List", "v:Last")

      jsonld1 = Enum.map(WOQL.to_jsonld(q1)["and"], &inspect/1)
      jsonld2 = Enum.map(WOQL.to_jsonld(q2)["and"], &inspect/1)

      assert jsonld1 != jsonld2
    end
  end
end
