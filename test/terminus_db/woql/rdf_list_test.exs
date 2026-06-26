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

  describe "rdflist_push/3" do
    test "builds an And query with add operations" do
      q = RDFList.rdflist_push("v:List", "v:Value", "v:NewHead")
      assert q.op == :and
      ops = Enum.map(q.args, & &1.op)
      assert :add_triple in ops
    end

    test "includes new_head_var in output" do
      q = RDFList.rdflist_push("v:List", "v:Value", "v:NewHead")
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "NewHead"
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

    test "guards deletes inside opt blocks" do
      q = RDFList.rdflist_clear("v:List", "v:NewList")
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "Optional"
      assert json =~ "DeleteTriple"
    end
  end

  describe "rdflist_length/2" do
    test "builds an And query" do
      q = RDFList.rdflist_length("v:List", "v:Len")
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

    test "includes delete_triple operations" do
      q = RDFList.rdflist_drop("v:List", 1)
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "DeleteTriple"
    end

    test "drop at 0 deletes from head" do
      q = RDFList.rdflist_drop("v:List", 0)
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "DeleteTriple"
      assert json =~ "rdf:first"
    end
  end

  describe "rdflist_swap/3" do
    test "builds an And query" do
      q = RDFList.rdflist_swap("v:List", 0, 2)
      assert q.op == :and
    end

    test "includes both delete_triple and add_triple write operations" do
      q = RDFList.rdflist_swap("v:List", 0, 2)
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "DeleteTriple"
      assert json =~ "AddTriple"
    end
  end

  describe "rdflist_nth0 with variable index" do
    test "does not crash and includes dec variable" do
      q = RDFList.rdflist_nth0("v:List", "v:Index", "v:Elem")
      assert q.op == :and
      json = Jason.encode!(WOQL.to_jsonld(q))
      assert json =~ "RDFList_dec"
    end
  end

  describe "rdflist_slice/4" do
    test "includes end_val in the generated query" do
      q = RDFList.rdflist_slice("v:List", 0, 3, "v:Result")
      assert q.op == :and
      json = Jason.encode!(WOQL.to_jsonld(q))
      # The slice should involve counting/navigation, not just collecting all
      refute json =~ "\"rdf:rest*\""
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
