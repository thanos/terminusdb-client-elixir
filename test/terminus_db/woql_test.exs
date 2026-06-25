defmodule TerminusDB.WOQLTest do
  use ExUnit.Case, async: true

  alias TerminusDB.{Config, Error, WOQL}
  import TerminusDB.Test.Helpers

  doctest TerminusDB.WOQL

  describe "triple/3" do
    test "builds a triple query" do
      q = WOQL.triple("v:S", "name", "v:N")
      assert q.op == :triple
      assert q.args == ["v:S", "name", "v:N"]
    end
  end

  describe "and_/1" do
    test "builds a conjunction" do
      q = WOQL.and_([WOQL.triple("v:S", "p", "v:O"), WOQL.eq("v:O", "Alice")])
      assert q.op == :and
      assert q.args != []
    end
  end

  describe "or_/1" do
    test "builds a disjunction" do
      q = WOQL.or_([WOQL.eq("v:N", "Alice"), WOQL.eq("v:N", "Bob")])
      assert q.op == :or
      assert q.args != []
    end
  end

  describe "eq/2" do
    test "builds an equality" do
      q = WOQL.eq("v:N", "Alice")
      assert q.op == :eq
      assert q.args == ["v:N", "Alice"]
    end
  end

  describe "select/2" do
    test "builds a select with variables and sub-query" do
      q = WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert q.op == :select
      assert q.args == [["v:Name"], %WOQL{op: :triple, args: ["v:P", "name", "v:Name"]}]
    end
  end

  describe "read_document/2" do
    test "builds a read_document query" do
      q = WOQL.read_document("Person/Alice", "v:Doc")
      assert q.op == :read_document
      assert q.args == ["Person/Alice", "v:Doc"]
    end
  end

  describe "type_of/2" do
    test "builds a type_of query" do
      q = WOQL.type_of("v:Person", "v:Type")
      assert q.op == :type_of
      assert q.args == ["v:Person", "v:Type"]
    end
  end

  describe "to_jsonld/1" do
    test "encodes a triple with variables" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:Person", "name", "v:Name"))

      assert jsonld["@type"] == "Triple"
      assert jsonld["subject"] == %{"@type" => "NodeValue", "variable" => "Person"}
      assert jsonld["predicate"] == %{"@type" => "NodeValue", "node" => "name"}
      assert jsonld["object"] == %{"@type" => "Value", "variable" => "Name"}
    end

    test "encodes a triple with constant string object as xsd:string literal" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:Person", "rdf:type", "@schema:Person"))

      assert jsonld["predicate"] == %{"@type" => "NodeValue", "node" => "rdf:type"}

      assert jsonld["object"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:string", "@value" => "@schema:Person"}
             }
    end

    test "encodes a triple with iri/1 object as NodeValue" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:Person", "rdf:type", WOQL.iri("@schema:Person")))

      assert jsonld["object"] == %{"@type" => "NodeValue", "node" => "@schema:Person"}
    end

    test "encodes a triple with numeric and boolean objects" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:S", "count", 42))

      assert jsonld["object"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:integer", "@value" => 42}
             }

      jsonld2 = WOQL.to_jsonld(WOQL.triple("v:S", "active", true))

      assert jsonld2["object"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:boolean", "@value" => true}
             }
    end

    test "encodes an and query" do
      jsonld = WOQL.to_jsonld(WOQL.and_([WOQL.triple("v:S", "p", "v:O")]))

      assert jsonld["@type"] == "And"
      assert is_list(jsonld["and"])
      assert length(jsonld["and"]) == 1
    end

    test "encodes an or query" do
      jsonld = WOQL.to_jsonld(WOQL.or_([WOQL.eq("v:N", "Alice")]))

      assert jsonld["@type"] == "Or"
      assert length(jsonld["or"]) == 1
    end

    test "encodes an eq query" do
      jsonld = WOQL.to_jsonld(WOQL.eq("v:N", "Alice"))

      assert jsonld["@type"] == "Equals"
      assert jsonld["left"] == %{"@type" => "Value", "variable" => "N"}

      assert jsonld["right"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
             }
    end

    test "encodes a select query" do
      jsonld = WOQL.to_jsonld(WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name")))

      assert jsonld["@type"] == "Select"
      assert jsonld["variables"] == ["Name"]
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "encodes a read_document query" do
      jsonld = WOQL.to_jsonld(WOQL.read_document("Person/Alice", "v:Doc"))

      assert jsonld["@type"] == "ReadDocument"
      assert jsonld["identifier"] == %{"@type" => "NodeValue", "node" => "Person/Alice"}
      assert jsonld["document"] == %{"@type" => "Value", "variable" => "Doc"}
    end

    test "encodes a type_of query" do
      jsonld = WOQL.to_jsonld(WOQL.type_of("v:Person", "v:Type"))

      assert jsonld["@type"] == "TypeOf"
      assert jsonld["value"] == %{"@type" => "Value", "variable" => "Person"}
      assert jsonld["type"] == %{"@type" => "Value", "variable" => "Type"}
    end

    test "encodes numeric and boolean values" do
      jsonld = WOQL.to_jsonld(WOQL.eq("v:Age", 30))

      assert jsonld["right"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:integer", "@value" => 30}
             }

      jsonld2 = WOQL.to_jsonld(WOQL.eq("v:Active", true))

      assert jsonld2["right"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:boolean", "@value" => true}
             }
    end

    test "encodes iri/1" do
      assert WOQL.iri("@schema:Person") == %{"@type" => "NodeValue", "node" => "@schema:Person"}
    end
  end

  describe "from_jsonld/1" do
    test "decodes a triple" do
      jsonld = %{
        "@type" => "Triple",
        "subject" => %{"@type" => "NodeValue", "variable" => "S"},
        "predicate" => %{"@type" => "NodeValue", "node" => "name"},
        "object" => %{"@type" => "Value", "variable" => "N"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :triple
      assert q.args == ["v:S", "name", "v:N"]
    end

    test "decodes an and query" do
      jsonld = %{
        "@type" => "And",
        "and" => [
          %{
            "@type" => "Triple",
            "subject" => %{"@type" => "NodeValue", "variable" => "S"},
            "predicate" => %{"@type" => "NodeValue", "node" => "p"},
            "object" => %{"@type" => "Value", "variable" => "O"}
          }
        ]
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :and
      assert q.args != []
    end

    test "decodes an or query" do
      jsonld = %{
        "@type" => "Or",
        "or" => [
          %{
            "@type" => "Equals",
            "left" => %{"@type" => "Value", "variable" => "N"},
            "right" => %{
              "@type" => "Value",
              "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
            }
          },
          %{
            "@type" => "Equals",
            "left" => %{"@type" => "Value", "variable" => "N"},
            "right" => %{
              "@type" => "Value",
              "data" => %{"@type" => "xsd:string", "@value" => "Bob"}
            }
          }
        ]
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :or
      assert length(q.args) == 2
    end

    test "decodes an eq query" do
      jsonld = %{
        "@type" => "Equals",
        "left" => %{"@type" => "Value", "variable" => "N"},
        "right" => %{
          "@type" => "Value",
          "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
        }
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :eq
      assert q.args == ["v:N", "Alice"]
    end

    test "decodes a select query" do
      jsonld = %{
        "@type" => "Select",
        "variables" => ["Name"],
        "query" => %{
          "@type" => "Triple",
          "subject" => %{"@type" => "NodeValue", "variable" => "P"},
          "predicate" => %{"@type" => "NodeValue", "node" => "name"},
          "object" => %{"@type" => "Value", "variable" => "Name"}
        }
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :select
      assert q.args == [["v:Name"], %WOQL{op: :triple, args: ["v:P", "name", "v:Name"]}]
    end

    test "decodes a read_document query" do
      jsonld = %{
        "@type" => "ReadDocument",
        "identifier" => %{"@type" => "NodeValue", "node" => "Person/Alice"},
        "document" => %{"@type" => "Value", "variable" => "Doc"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :read_document
      assert q.args == ["Person/Alice", "v:Doc"]
    end

    test "decodes a type_of query" do
      jsonld = %{
        "@type" => "TypeOf",
        "value" => %{"@type" => "Value", "variable" => "Person"},
        "type" => %{"@type" => "Value", "variable" => "Type"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :type_of
      assert q.args == ["v:Person", "v:Type"]
    end
  end

  describe "literal helpers" do
    test "var/1 prefixes with v:" do
      assert WOQL.var("Person") == "v:Person"
      assert WOQL.var("v:Person") == "v:Person"
    end

    test "string/1 wraps as xsd:string literal" do
      assert WOQL.string("hello") == %{"@type" => "xsd:string", "@value" => "hello"}
    end

    test "boolean/1 wraps as xsd:boolean literal" do
      assert WOQL.boolean(true) == %{"@type" => "xsd:boolean", "@value" => true}
    end

    test "datetime/1 wraps as xsd:dateTime literal" do
      assert WOQL.datetime("2026-01-15T10:30:00Z") ==
               %{"@type" => "xsd:dateTime", "@value" => "2026-01-15T10:30:00Z"}
    end

    test "date/1 wraps as xsd:date literal" do
      assert WOQL.date("2026-01-15") == %{"@type" => "xsd:date", "@value" => "2026-01-15"}
    end

    test "literal/2 prefixes type with xsd: when no colon" do
      assert WOQL.literal("42", "integer") == %{"@type" => "xsd:integer", "@value" => "42"}
    end

    test "literal/2 preserves type when it already has a colon" do
      assert WOQL.literal("foo", "custom:type") ==
               %{"@type" => "custom:type", "@value" => "foo"}
    end

    test "encode_value wraps raw literal dicts in Value" do
      jsonld = WOQL.to_jsonld(WOQL.triple("v:S", "name", WOQL.string("hello")))

      assert jsonld["object"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:string", "@value" => "hello"}
             }
    end
  end

  describe "true_/0" do
    test "builds a true query" do
      q = WOQL.true_()
      assert q.op == true
      assert q.args == []
    end

    test "encodes as True" do
      jsonld = WOQL.to_jsonld(WOQL.true_())
      assert jsonld == %{"@type" => "True"}
    end

    test "decodes from True" do
      q = WOQL.from_jsonld(%{"@type" => "True"})
      assert q.op == true
    end

    test "round-trips" do
      q = WOQL.true_()
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "logical combinators" do
    test "not_/1 builds a negation" do
      q = WOQL.not_(WOQL.eq("v:N", "Alice"))
      assert q.op == :not
      assert q.args == [WOQL.eq("v:N", "Alice")]
    end

    test "encodes not_ as Not" do
      jsonld = WOQL.to_jsonld(WOQL.not_(WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Not"
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "opt/1 builds an optional" do
      q = WOQL.opt(WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :opt
    end

    test "optional/1 is an alias for opt/1" do
      assert WOQL.optional(WOQL.triple("v:S", "p", "v:O")) ==
               WOQL.opt(WOQL.triple("v:S", "p", "v:O"))
    end

    test "encodes opt as Optional" do
      jsonld = WOQL.to_jsonld(WOQL.opt(WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Optional"
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "once/1 builds a once" do
      q = WOQL.once(WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :once
    end

    test "encodes once as Once" do
      jsonld = WOQL.to_jsonld(WOQL.once(WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Once"
    end

    test "immediately/1 builds an immediately" do
      q = WOQL.immediately(WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :immediately
    end

    test "encodes immediately as Immediately" do
      jsonld = WOQL.to_jsonld(WOQL.immediately(WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Immediately"
    end

    test "decodes Not" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "Not",
          "query" => %{
            "@type" => "Triple",
            "subject" => %{"@type" => "NodeValue", "variable" => "S"},
            "predicate" => %{"@type" => "NodeValue", "node" => "p"},
            "object" => %{"@type" => "Value", "variable" => "O"}
          }
        })

      assert q.op == :not
      assert q.args == [WOQL.triple("v:S", "p", "v:O")]
    end

    test "decodes Optional" do
      q = WOQL.from_jsonld(%{"@type" => "Optional", "query" => %{"@type" => "True"}})
      assert q.op == :opt
    end

    test "decodes Once" do
      q = WOQL.from_jsonld(%{"@type" => "Once", "query" => %{"@type" => "True"}})
      assert q.op == :once
    end

    test "decodes Immediately" do
      q = WOQL.from_jsonld(%{"@type" => "Immediately", "query" => %{"@type" => "True"}})
      assert q.op == :immediately
    end

    test "round-trips not_" do
      q = WOQL.not_(WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips opt" do
      q = WOQL.opt(WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips once" do
      q = WOQL.once(WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips immediately" do
      q = WOQL.immediately(WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "query modifiers" do
    test "distinct/2 builds and encodes" do
      q = WOQL.distinct(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert q.op == :distinct

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Distinct"
      assert jsonld["variables"] == ["Name"]
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "limit/2 builds and encodes" do
      q = WOQL.limit(10, WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :limit

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Limit"
      assert jsonld["limit"] == 10
    end

    test "start/2 builds and encodes" do
      q = WOQL.start(5, WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :start

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Start"
      assert jsonld["start"] == 5
    end

    test "order_by/2 with tuple list" do
      q = WOQL.order_by([{"v:Name", :asc}], WOQL.triple("v:S", "name", "v:Name"))
      assert q.op == :order_by

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "OrderBy"

      assert jsonld["ordering"] == [
               %{"@type" => "OrderTemplate", "variable" => "Name", "order" => "asc"}
             ]
    end

    test "order_by/2 with keyword list" do
      q = WOQL.order_by([name: :desc], WOQL.triple("v:S", "name", "v:Name"))

      jsonld = WOQL.to_jsonld(q)

      assert jsonld["ordering"] == [
               %{"@type" => "OrderTemplate", "variable" => "name", "order" => "desc"}
             ]
    end

    test "order_by/2 with multiple specs" do
      q = WOQL.order_by([{"v:Time", :asc}, {"v:Name", :desc}], WOQL.triple("v:S", "p", "v:O"))

      jsonld = WOQL.to_jsonld(q)
      assert length(jsonld["ordering"]) == 2
      assert hd(jsonld["ordering"])["variable"] == "Time"
      assert hd(jsonld["ordering"])["order"] == "asc"
    end

    test "group_by/4 builds and encodes" do
      q =
        WOQL.group_by(
          ["v:Type"],
          "v:Template",
          "v:Grouped",
          WOQL.triple("v:S", "rdf:type", "v:Type")
        )

      assert q.op == :group_by

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "GroupBy"
      assert jsonld["group_by"] == ["Type"]
    end

    test "count/2 builds and encodes" do
      q = WOQL.count("v:N", WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :count

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Count"
      assert jsonld["count"] == %{"@type" => "Value", "variable" => "N"}
    end

    test "collect/3 builds and encodes" do
      q = WOQL.collect("v:Template", "v:Into", WOQL.triple("v:S", "p", "v:O"))
      assert q.op == :collect

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Collect"
      assert jsonld["template"] == %{"@type" => "Value", "variable" => "Template"}
    end

    test "star/0 builds a triple with default variables" do
      q = WOQL.star()
      assert q.op == :triple
      assert q.args == ["v:Subject", "v:Predicate", "v:Object"]
    end

    test "all/0 is an alias for star/0" do
      assert WOQL.all() == WOQL.star()
    end

    test "decodes distinct" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "Distinct",
          "variables" => ["Name"],
          "query" => %{"@type" => "True"}
        })

      assert q.op == :distinct
    end

    test "decodes limit" do
      q = WOQL.from_jsonld(%{"@type" => "Limit", "limit" => 5, "query" => %{"@type" => "True"}})
      assert q.op == :limit
      assert q.args == [5, WOQL.true_()]
    end

    test "decodes order_by" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "OrderBy",
          "ordering" => [%{"@type" => "OrderTemplate", "variable" => "Name", "order" => "asc"}],
          "query" => %{"@type" => "True"}
        })

      assert q.op == :order_by
    end

    test "round-trips distinct" do
      q = WOQL.distinct(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips limit" do
      q = WOQL.limit(10, WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips start" do
      q = WOQL.start(5, WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips order_by with tuple list" do
      q = WOQL.order_by([{"v:Name", :asc}], WOQL.triple("v:S", "name", "v:Name"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips order_by with keyword list" do
      q = WOQL.order_by([name: :desc], WOQL.triple("v:S", "name", "v:Name"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips group_by" do
      q = WOQL.group_by(["v:Type"], "v:Template", "v:Grouped", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips count" do
      q = WOQL.count("v:N", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips collect" do
      q = WOQL.collect("v:Template", "v:Into", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "graph patterns" do
    test "quad/4 builds and encodes with graph field" do
      q = WOQL.quad("v:S", "name", "v:N", "instance")
      assert q.op == :quad

      jsonld = WOQL.to_jsonld(q)
      assert jsonld["@type"] == "Triple"
      assert jsonld["graph"] == "instance"
    end

    test "added_triple/3 encodes as AddedTriple" do
      jsonld = WOQL.to_jsonld(WOQL.added_triple("v:S", "name", "v:N"))
      assert jsonld["@type"] == "AddedTriple"
    end

    test "removed_triple/3 encodes as DeletedTriple" do
      jsonld = WOQL.to_jsonld(WOQL.removed_triple("v:S", "name", "v:N"))
      assert jsonld["@type"] == "DeletedTriple"
    end

    test "added_quad/4 encodes as AddedTriple with graph" do
      jsonld = WOQL.to_jsonld(WOQL.added_quad("v:S", "name", "v:N", "instance"))
      assert jsonld["@type"] == "AddedTriple"
      assert jsonld["graph"] == "instance"
    end

    test "removed_quad/4 encodes as DeletedTriple with graph" do
      jsonld = WOQL.to_jsonld(WOQL.removed_quad("v:S", "name", "v:N", "instance"))
      assert jsonld["@type"] == "DeletedTriple"
      assert jsonld["graph"] == "instance"
    end

    test "add_triple/3 encodes as AddTriple" do
      jsonld = WOQL.to_jsonld(WOQL.add_triple("v:S", "name", "Alice"))
      assert jsonld["@type"] == "AddTriple"
    end

    test "delete_triple/3 encodes as DeleteTriple" do
      jsonld = WOQL.to_jsonld(WOQL.delete_triple("v:S", "name", "v:O"))
      assert jsonld["@type"] == "DeleteTriple"
    end

    test "add_quad/4 encodes as AddTriple with graph" do
      jsonld = WOQL.to_jsonld(WOQL.add_quad("v:S", "name", "Alice", "instance"))
      assert jsonld["@type"] == "AddTriple"
      assert jsonld["graph"] == "instance"
    end

    test "delete_quad/4 encodes as DeleteTriple with graph" do
      jsonld = WOQL.to_jsonld(WOQL.delete_quad("v:S", "name", "v:O", "instance"))
      assert jsonld["@type"] == "DeleteTriple"
      assert jsonld["graph"] == "instance"
    end

    test "update_triple/3 composes and_ with opt delete + add" do
      q = WOQL.update_triple("v:S", "name", "Alice")
      assert q.op == :and
      assert length(q.args) == 2
      assert hd(q.args).op == :opt
      assert hd(q.args).args |> hd() |> Map.get(:op) == :delete_triple
    end

    test "update_quad/4 composes and_ with opt delete + add" do
      q = WOQL.update_quad("v:S", "name", "Alice", "instance")
      assert q.op == :and
      assert length(q.args) == 2
    end

    test "update_triple/3 round-trips as and_/opt/delete_triple/add_triple" do
      q = WOQL.update_triple("v:S", "name", "Alice")
      decoded = WOQL.from_jsonld(WOQL.to_jsonld(q))
      assert decoded.op == :and
      assert length(decoded.args) == 2
      [opt, add] = decoded.args
      assert opt.op == :opt
      assert opt.args |> hd() |> Map.get(:op) == :delete_triple
      assert add.op == :add_triple
    end

    test "decodes quad from Triple with graph" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "Triple",
          "subject" => %{"@type" => "NodeValue", "variable" => "S"},
          "predicate" => %{"@type" => "NodeValue", "node" => "name"},
          "object" => %{"@type" => "Value", "variable" => "N"},
          "graph" => "instance"
        })

      assert q.op == :quad
      assert q.args == ["v:S", "name", "v:N", "instance"]
    end

    test "decodes AddedTriple" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "AddedTriple",
          "subject" => %{"@type" => "NodeValue", "variable" => "S"},
          "predicate" => %{"@type" => "NodeValue", "node" => "p"},
          "object" => %{"@type" => "Value", "variable" => "O"}
        })

      assert q.op == :added_triple
    end

    test "decodes AddTriple" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "AddTriple",
          "subject" => %{"@type" => "NodeValue", "node" => "Person/Alice"},
          "predicate" => %{"@type" => "NodeValue", "node" => "name"},
          "object" => %{
            "@type" => "Value",
            "data" => %{"@type" => "xsd:string", "@value" => "Alice"}
          }
        })

      assert q.op == :add_triple
    end

    test "decodes DeleteTriple with graph as delete_quad" do
      q =
        WOQL.from_jsonld(%{
          "@type" => "DeleteTriple",
          "subject" => %{"@type" => "NodeValue", "variable" => "S"},
          "predicate" => %{"@type" => "NodeValue", "node" => "p"},
          "object" => %{"@type" => "Value", "variable" => "O"},
          "graph" => "instance"
        })

      assert q.op == :delete_quad
    end

    test "round-trips quad" do
      q = WOQL.quad("v:S", "name", "v:N", "instance")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips added_triple" do
      q = WOQL.added_triple("v:S", "name", "v:N")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips removed_triple" do
      q = WOQL.removed_triple("v:S", "name", "v:N")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips add_triple" do
      q = WOQL.add_triple("v:S", "name", "Alice")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips delete_triple" do
      q = WOQL.delete_triple("v:S", "name", "v:O")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips add_quad" do
      q = WOQL.add_quad("v:S", "name", "Alice", "instance")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips delete_quad" do
      q = WOQL.delete_quad("v:S", "name", "v:O", "instance")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips added_quad" do
      q = WOQL.added_quad("v:S", "name", "v:N", "instance")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips removed_quad" do
      q = WOQL.removed_quad("v:S", "name", "v:N", "instance")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "comparison" do
    test "less/2 encodes as Less" do
      jsonld = WOQL.to_jsonld(WOQL.less("v:Age", 30))
      assert jsonld["@type"] == "Less"
      assert jsonld["left"] == %{"@type" => "Value", "variable" => "Age"}
    end

    test "greater/2 encodes as Greater" do
      assert WOQL.to_jsonld(WOQL.greater("v:Age", 30))["@type"] == "Greater"
    end

    test "gte/2 encodes as Gte" do
      assert WOQL.to_jsonld(WOQL.gte("v:Age", 30))["@type"] == "Gte"
    end

    test "lte/2 encodes as Lte" do
      assert WOQL.to_jsonld(WOQL.lte("v:Age", 30))["@type"] == "Lte"
    end

    test "like/3 encodes as Like with distance" do
      jsonld = WOQL.to_jsonld(WOQL.like("v:Name", "Alice", 2))
      assert jsonld["@type"] == "Like"

      assert jsonld["distance"] == %{
               "@type" => "Value",
               "data" => %{"@type" => "xsd:integer", "@value" => 2}
             }
    end

    test "round-trips less" do
      q = WOQL.less("v:Age", 30)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips greater" do
      q = WOQL.greater("v:Age", 30)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips gte" do
      q = WOQL.gte("v:Age", 30)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips lte" do
      q = WOQL.lte("v:Age", 30)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips like" do
      q = WOQL.like("v:Name", "Alice", 2)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "schema ops" do
    test "isa/2 encodes as IsA with NodeValue" do
      jsonld = WOQL.to_jsonld(WOQL.isa("v:X", WOQL.iri("@schema:Person")))
      assert jsonld["@type"] == "IsA"
      assert jsonld["element"] == %{"@type" => "NodeValue", "variable" => "X"}
      assert jsonld["type"] == %{"@type" => "NodeValue", "node" => "@schema:Person"}
    end

    test "sub/2 encodes as Subsumption" do
      jsonld = WOQL.to_jsonld(WOQL.sub(WOQL.iri("@schema:Animal"), WOQL.iri("@schema:Dog")))
      assert jsonld["@type"] == "Subsumption"
      assert jsonld["parent"] == %{"@type" => "NodeValue", "node" => "@schema:Animal"}
    end

    test "subsumption/2 is an alias for sub/2" do
      assert WOQL.subsumption(WOQL.iri("A"), WOQL.iri("B")) ==
               WOQL.sub(WOQL.iri("A"), WOQL.iri("B"))
    end

    test "cast/3 encodes as Typecast" do
      jsonld = WOQL.to_jsonld(WOQL.cast("v:Val", "xsd:integer", "v:Result"))
      assert jsonld["@type"] == "Typecast"
      assert jsonld["value"] == %{"@type" => "Value", "variable" => "Val"}
    end

    test "typecast/3 is an alias for cast/3" do
      assert WOQL.typecast("v:V", "t", "v:R") == WOQL.cast("v:V", "t", "v:R")
    end

    test "round-trips isa" do
      q = WOQL.isa("v:X", "@schema:Person")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips sub" do
      q = WOQL.sub("@schema:Animal", "@schema:Dog")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips cast" do
      q = WOQL.cast("v:Val", "xsd:integer", "v:Result")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "arithmetic" do
    test "eval/2 encodes as Eval with ArithmeticValue expression" do
      q = WOQL.eval(WOQL.plus(["v:X", 5]), "v:Result")
      jsonld = WOQL.to_jsonld(q)

      assert jsonld["@type"] == "Eval"
      assert jsonld["expression"]["@type"] == "Plus"
      assert jsonld["result"] == %{"@type" => "Value", "variable" => "Result"}
    end

    test "plus/1 encodes as Plus with ArithmeticValue arguments" do
      jsonld = WOQL.to_jsonld(WOQL.plus(["v:X", 5, 3]))

      assert jsonld["@type"] == "Plus"
      assert length(jsonld["arguments"]) == 3
      assert hd(jsonld["arguments"]) == %{"@type" => "ArithmeticValue", "variable" => "X"}

      assert Enum.at(jsonld["arguments"], 1) ==
               %{
                 "@type" => "ArithmeticValue",
                 "data" => %{"@type" => "xsd:integer", "@value" => 5}
               }
    end

    test "minus/1 encodes as Minus" do
      assert WOQL.to_jsonld(WOQL.minus(["v:X", 5]))["@type"] == "Minus"
    end

    test "times/1 encodes as Times" do
      assert WOQL.to_jsonld(WOQL.times(["v:X", 5]))["@type"] == "Times"
    end

    test "divide/1 encodes as Divide" do
      assert WOQL.to_jsonld(WOQL.divide(["v:X", 5]))["@type"] == "Divide"
    end

    test "div/1 encodes as Div" do
      assert WOQL.to_jsonld(WOQL.div(["v:X", 5]))["@type"] == "Div"
    end

    test "exp/2 encodes as Exp" do
      jsonld = WOQL.to_jsonld(WOQL.exp("v:X", 2))
      assert jsonld["@type"] == "Exp"
      assert jsonld["first"] == %{"@type" => "ArithmeticValue", "variable" => "X"}
    end

    test "floor/1 encodes as Floor" do
      jsonld = WOQL.to_jsonld(WOQL.floor("v:X"))
      assert jsonld["@type"] == "Floor"
      assert jsonld["data"] == %{"@type" => "ArithmeticValue", "variable" => "X"}
    end

    test "sum/2 encodes as Sum" do
      jsonld = WOQL.to_jsonld(WOQL.sum("v:List", "v:Result"))
      assert jsonld["@type"] == "Sum"
      assert jsonld["list"] == %{"@type" => "Value", "variable" => "List"}
    end

    test "nested arithmetic encodes recursively" do
      q = WOQL.plus([WOQL.minus(["v:X", 1]), WOQL.times(["v:Y", 2])])
      jsonld = WOQL.to_jsonld(q)

      assert jsonld["@type"] == "Plus"
      assert Enum.at(jsonld["arguments"], 0)["@type"] == "Minus"
      assert Enum.at(jsonld["arguments"], 1)["@type"] == "Times"
    end

    test "round-trips plus" do
      q = WOQL.plus(["v:X", 5])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips minus" do
      q = WOQL.minus(["v:X", 5])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips times" do
      q = WOQL.times(["v:X", 5])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips divide" do
      q = WOQL.divide(["v:X", 5])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips div" do
      q = WOQL.div(["v:X", 5])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips exp" do
      q = WOQL.exp("v:X", 2)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips floor" do
      q = WOQL.floor("v:X")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips sum" do
      q = WOQL.sum("v:List", "v:Result")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips nested arithmetic" do
      q = WOQL.plus([WOQL.minus(["v:X", 1]), WOQL.times(["v:Y", 2])])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "string ops" do
    test "concat/2 encodes as Concatenate with DataValue list" do
      jsonld = WOQL.to_jsonld(WOQL.concat(["v:First", " ", "v:Last"], "v:Full"))
      assert jsonld["@type"] == "Concatenate"
      assert length(jsonld["list"]) == 3
      assert hd(jsonld["list"]) == %{"@type" => "DataValue", "variable" => "First"}
    end

    test "join/3 encodes as Join" do
      assert WOQL.to_jsonld(WOQL.join("v:List", ", ", "v:Result"))["@type"] == "Join"
    end

    test "substr/5 encodes as Substring" do
      assert WOQL.to_jsonld(WOQL.substr("v:String", 5, "v:Sub"))["@type"] == "Substring"
    end

    test "trim/2 encodes as Trim" do
      assert WOQL.to_jsonld(WOQL.trim("v:U", "v:T"))["@type"] == "Trim"
    end

    test "upper/2 encodes as Upper" do
      assert WOQL.to_jsonld(WOQL.upper("v:I", "v:R"))["@type"] == "Upper"
    end

    test "lower/2 encodes as Lower" do
      assert WOQL.to_jsonld(WOQL.lower("v:I", "v:R"))["@type"] == "Lower"
    end

    test "pad/4 encodes as Pad" do
      assert WOQL.to_jsonld(WOQL.pad("v:I", "0", 10, "v:R"))["@type"] == "Pad"
    end

    test "split/3 encodes as Split" do
      assert WOQL.to_jsonld(WOQL.split("v:S", ",", "v:R"))["@type"] == "Split"
    end

    test "length/2 encodes as Length" do
      assert WOQL.to_jsonld(WOQL.length("v:L", "v:N"))["@type"] == "Length"
    end

    test "regexp/3 encodes as Regexp" do
      assert WOQL.to_jsonld(WOQL.regexp("pat", "v:S", "v:R"))["@type"] == "Regexp"
    end

    test "concatenate/2 is alias for concat/2" do
      assert WOQL.concatenate(["a", "b"], "v:R") == WOQL.concat(["a", "b"], "v:R")
    end

    test "substring/5 is alias for substr/5" do
      assert WOQL.substring("v:S", 5, "v:Sub") == WOQL.substr("v:S", 5, "v:Sub")
    end

    test "round-trips concat" do
      q = WOQL.concat(["v:First", "v:Last"], "v:Full")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips join" do
      q = WOQL.join("v:List", ", ", "v:Result")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips substr" do
      q = WOQL.substr("v:String", 5, "v:Sub", 0, 0)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips trim" do
      q = WOQL.trim("v:U", "v:T")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips upper" do
      q = WOQL.upper("v:I", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips lower" do
      q = WOQL.lower("v:I", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips pad" do
      q = WOQL.pad("v:I", "0", 10, "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips split" do
      q = WOQL.split("v:S", ",", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips length" do
      q = WOQL.length("v:L", "v:N")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips regexp" do
      q = WOQL.regexp("pat", "v:S", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "list/set ops" do
    test "dot/3 encodes as Dot" do
      jsonld = WOQL.to_jsonld(WOQL.dot("v:Doc", "field", "v:Value"))
      assert jsonld["@type"] == "Dot"
      assert jsonld["document"] == %{"@type" => "Value", "variable" => "Doc"}

      assert jsonld["field"] == %{
               "@type" => "DataValue",
               "data" => %{"@type" => "xsd:string", "@value" => "field"}
             }
    end

    test "member/2 encodes as Member" do
      assert WOQL.to_jsonld(WOQL.member("v:Item", "v:List"))["@type"] == "Member"
    end

    test "slice/4 encodes as Slice" do
      assert WOQL.to_jsonld(WOQL.slice("v:L", "v:R", 0, 5))["@type"] == "Slice"
    end

    test "set_difference/3 encodes as SetDifference" do
      assert WOQL.to_jsonld(WOQL.set_difference("v:A", "v:B", "v:R"))["@type"] == "SetDifference"
    end

    test "set_intersection/3 encodes as SetIntersection" do
      assert WOQL.to_jsonld(WOQL.set_intersection("v:A", "v:B", "v:R"))["@type"] ==
               "SetIntersection"
    end

    test "set_union/3 encodes as SetUnion" do
      assert WOQL.to_jsonld(WOQL.set_union("v:A", "v:B", "v:R"))["@type"] == "SetUnion"
    end

    test "set_member/2 encodes as SetMember" do
      assert WOQL.to_jsonld(WOQL.set_member("v:E", "v:S"))["@type"] == "SetMember"
    end

    test "list_to_set/2 encodes as ListToSet" do
      assert WOQL.to_jsonld(WOQL.list_to_set("v:L", "v:S"))["@type"] == "ListToSet"
    end

    test "round-trips dot" do
      q = WOQL.dot("v:Doc", "field", "v:Value")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips member" do
      q = WOQL.member("v:Item", "v:List")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips slice" do
      q = WOQL.slice("v:L", "v:R", 0, 5)
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips set_difference" do
      q = WOQL.set_difference("v:A", "v:B", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips set_intersection" do
      q = WOQL.set_intersection("v:A", "v:B", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips set_union" do
      q = WOQL.set_union("v:A", "v:B", "v:R")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips set_member" do
      q = WOQL.set_member("v:E", "v:S")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips list_to_set" do
      q = WOQL.list_to_set("v:L", "v:S")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "path DSL - string parser" do
    test "parses simple predicate" do
      assert WOQL.Path.parse("friend") == {:pred, "friend"}
    end

    test "parses inverse" do
      assert WOQL.Path.parse("<friend") == {:inverse, "friend"}
    end

    test "parses star" do
      assert WOQL.Path.parse("friend*") == {:star, {:pred, "friend"}}
    end

    test "parses plus" do
      assert WOQL.Path.parse("friend+") == {:plus, {:pred, "friend"}}
    end

    test "parses exact times {n}" do
      assert WOQL.Path.parse("friend{3}") == {:times, {:pred, "friend"}, 3, 3}
    end

    test "parses range times {n,m}" do
      assert WOQL.Path.parse("friend{1,3}") == {:times, {:pred, "friend"}, 1, 3}
    end

    test "parses unbounded times {n,}" do
      assert WOQL.Path.parse("friend{3,}") == {:times, {:pred, "friend"}, 3, nil}
    end

    test "parses alternation" do
      assert WOQL.Path.parse("friend|foe") == {:or, [{:pred, "friend"}, {:pred, "foe"}]}
    end

    test "parses sequence" do
      assert WOQL.Path.parse("friend,location") ==
               {:seq, [{:pred, "friend"}, {:pred, "location"}]}
    end

    test "parses any predicate" do
      assert WOQL.Path.parse(".") == {:any}
    end

    test "parses grouping" do
      assert WOQL.Path.parse("(friend|foe)*") ==
               {:star, {:or, [{:pred, "friend"}, {:pred, "foe"}]}}
    end

    test "parses complex pattern" do
      assert WOQL.Path.parse("<friend{1,3}") ==
               {:times, {:inverse, "friend"}, 1, 3}
    end

    test "raises on empty string" do
      assert_raise ArgumentError, fn -> WOQL.Path.parse("") end
    end

    test "raises on unbalanced parens" do
      assert_raise ArgumentError, fn -> WOQL.Path.parse("(friend") end
    end

    test "raises on invalid quantifier" do
      assert_raise ArgumentError, fn -> WOQL.Path.parse("friend{") end
    end

    test "raises on trailing pipe" do
      assert_raise ArgumentError, fn -> WOQL.Path.parse("friend|") end
    end
  end

  describe "path DSL - structured builders" do
    test "path_pred/1" do
      assert WOQL.Path.path_pred("friend") == {:pred, "friend"}
    end

    test "path_any/0" do
      assert WOQL.Path.path_any() == {:any}
    end

    test "path_seq/1" do
      assert WOQL.Path.path_seq([{:pred, "a"}, {:pred, "b"}]) ==
               {:seq, [{:pred, "a"}, {:pred, "b"}]}
    end

    test "path_or/1" do
      assert WOQL.Path.path_or([{:pred, "a"}, {:pred, "b"}]) ==
               {:or, [{:pred, "a"}, {:pred, "b"}]}
    end

    test "path_star/1" do
      assert WOQL.Path.path_star({:pred, "friend"}) == {:star, {:pred, "friend"}}
    end

    test "path_plus/1" do
      assert WOQL.Path.path_plus({:pred, "friend"}) == {:plus, {:pred, "friend"}}
    end

    test "path_times/3" do
      assert WOQL.Path.path_times({:pred, "friend"}, 1, 3) == {:times, {:pred, "friend"}, 1, 3}
    end

    test "path_inverse/1" do
      assert WOQL.Path.path_inverse("friend") == {:inverse, "friend"}
    end
  end

  describe "path DSL - serialization" do
    test "serializes pred to PathPredicate" do
      assert WOQL.Path.to_jsonld({:pred, "friend"}) == %{
               "@type" => "PathPredicate",
               "predicate" => "friend"
             }
    end

    test "serializes any to PathPredicate with dot" do
      assert WOQL.Path.to_jsonld({:any}) == %{"@type" => "PathPredicate", "predicate" => "."}
    end

    test "serializes star to PathStar" do
      jsonld = WOQL.Path.to_jsonld({:star, {:pred, "friend"}})
      assert jsonld["@type"] == "PathStar"
      assert jsonld["star"]["@type"] == "PathPredicate"
    end

    test "serializes times with to field" do
      jsonld = WOQL.Path.to_jsonld({:times, {:pred, "f"}, 1, 3})
      assert jsonld["@type"] == "PathTimes"
      assert jsonld["from"] == 1
      assert jsonld["to"] == 3
    end

    test "serializes times without to field when nil" do
      jsonld = WOQL.Path.to_jsonld({:times, {:pred, "f"}, 3, nil})
      assert jsonld["from"] == 3
      refute Map.has_key?(jsonld, "to")
    end

    test "deserializes PathPredicate" do
      assert WOQL.Path.from_jsonld(%{"@type" => "PathPredicate", "predicate" => "friend"}) ==
               {:pred, "friend"}
    end

    test "deserializes PathStar" do
      jsonld = %{
        "@type" => "PathStar",
        "star" => %{"@type" => "PathPredicate", "predicate" => "friend"}
      }

      assert WOQL.Path.from_jsonld(jsonld) == {:star, {:pred, "friend"}}
    end

    test "round-trips PathOr AST" do
      ast = {:or, [{:pred, "a"}, {:pred, "b"}]}
      assert WOQL.Path.from_jsonld(WOQL.Path.to_jsonld(ast)) == ast
    end

    test "round-trips PathSequence AST" do
      ast = {:seq, [{:pred, "a"}, {:star, {:pred, "b"}}]}
      assert WOQL.Path.from_jsonld(WOQL.Path.to_jsonld(ast)) == ast
    end

    test "round-trips PathTimes AST" do
      ast = {:times, {:pred, "f"}, 1, 3}
      assert WOQL.Path.from_jsonld(WOQL.Path.to_jsonld(ast)) == ast
    end

    test "round-trips InversePathPredicate AST" do
      ast = {:inverse, "friend"}
      assert WOQL.Path.from_jsonld(WOQL.Path.to_jsonld(ast)) == ast
    end
  end

  describe "path/3 and path/4" do
    test "path/3 builds with string pattern" do
      q = WOQL.path("v:S", "friend*", "v:O")
      assert q.op == :path
      assert q.args == ["v:S", {:star, {:pred, "friend"}}, "v:O"]
    end

    test "path/3 builds with AST pattern" do
      ast = WOQL.Path.path_star(WOQL.Path.path_pred("friend"))
      q = WOQL.path("v:S", ast, "v:O")
      assert q.args == ["v:S", ast, "v:O"]
    end

    test "path/4 builds with path var" do
      q = WOQL.path("v:S", "friend*", "v:O", "v:Path")
      assert q.args == ["v:S", {:star, {:pred, "friend"}}, "v:O", "v:Path"]
    end

    test "encodes path/3 as Path" do
      jsonld = WOQL.to_jsonld(WOQL.path("v:S", "friend*", "v:O"))
      assert jsonld["@type"] == "Path"
      assert jsonld["subject"] == %{"@type" => "NodeValue", "variable" => "S"}
      assert jsonld["pattern"]["@type"] == "PathStar"
      assert jsonld["object"] == %{"@type" => "Value", "variable" => "O"}
      refute Map.has_key?(jsonld, "path")
    end

    test "encodes path/4 with path var" do
      jsonld = WOQL.to_jsonld(WOQL.path("v:S", "friend", "v:O", "v:Path"))
      assert jsonld["path"] == %{"@type" => "Value", "variable" => "Path"}
    end

    test "decodes path/3" do
      jsonld = %{
        "@type" => "Path",
        "subject" => %{"@type" => "NodeValue", "variable" => "S"},
        "pattern" => %{"@type" => "PathPredicate", "predicate" => "friend"},
        "object" => %{"@type" => "Value", "variable" => "O"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :path
      assert q.args == ["v:S", {:pred, "friend"}, "v:O"]
    end

    test "decodes path/4" do
      jsonld = %{
        "@type" => "Path",
        "subject" => %{"@type" => "NodeValue", "variable" => "S"},
        "pattern" => %{"@type" => "PathPredicate", "predicate" => "friend"},
        "object" => %{"@type" => "Value", "variable" => "O"},
        "path" => %{"@type" => "Value", "variable" => "Path"}
      }

      q = WOQL.from_jsonld(jsonld)
      assert q.op == :path
      assert q.args == ["v:S", {:pred, "friend"}, "v:O", "v:Path"]
    end

    test "round-trips path/3 with string pattern" do
      q = WOQL.path("v:S", "friend*", "v:O")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips path/4 with path var" do
      q = WOQL.path("v:S", "friend*", "v:O", "v:Path")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips path/3 with complex pattern" do
      q = WOQL.path("v:S", "(friend|foe)*", "v:O")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips path/3 with inverse pattern" do
      q = WOQL.path("v:S", "<friend", "v:O")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips path/3 with structured pattern" do
      ast =
        WOQL.Path.path_star(
          WOQL.Path.path_or([WOQL.Path.path_pred("a"), WOQL.Path.path_pred("b")])
        )

      q = WOQL.path("v:S", ast, "v:O")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "ID generation" do
    test "unique/3 encodes as HashKey" do
      jsonld = WOQL.to_jsonld(WOQL.unique("Person/", ["v:Name", "v:Email"], "v:ID"))
      assert jsonld["@type"] == "HashKey"

      assert jsonld["base"] == %{
               "@type" => "DataValue",
               "data" => %{"@type" => "xsd:string", "@value" => "Person/"}
             }

      assert jsonld["uri"] == %{"@type" => "NodeValue", "variable" => "ID"}
      assert length(jsonld["key_list"]) == 2
    end

    test "idgen/3 encodes as LexicalKey" do
      assert WOQL.to_jsonld(WOQL.idgen("Person/", ["v:Name"], "v:ID"))["@type"] == "LexicalKey"
    end

    test "idgenerator/3 is alias for idgen/3" do
      assert WOQL.idgenerator("P/", ["v:N"], "v:ID") == WOQL.idgen("P/", ["v:N"], "v:ID")
    end

    test "idgen_random/2 encodes as RandomKey" do
      jsonld = WOQL.to_jsonld(WOQL.idgen_random("Person/", "v:ID"))
      assert jsonld["@type"] == "RandomKey"
      assert jsonld["uri"] == %{"@type" => "NodeValue", "variable" => "ID"}
    end

    test "random_idgen/2 is alias for idgen_random/2" do
      assert WOQL.random_idgen("P/", "v:ID") == WOQL.idgen_random("P/", "v:ID")
    end

    test "round-trips unique" do
      q = WOQL.unique("Person/", ["v:Name", "v:Email"], "v:ID")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips idgen" do
      q = WOQL.idgen("Person/", ["v:Name"], "v:ID")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips idgen_random" do
      q = WOQL.idgen_random("Person/", "v:ID")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "document mutations" do
    test "insert_document/1 encodes as InsertDocument" do
      jsonld = WOQL.to_jsonld(WOQL.insert_document("v:Doc"))
      assert jsonld["@type"] == "InsertDocument"
      assert jsonld["document"] == %{"@type" => "Value", "variable" => "Doc"}
      refute Map.has_key?(jsonld, "identifier")
    end

    test "insert_document/2 with map encodes document as DictionaryTemplate" do
      jsonld = WOQL.to_jsonld(WOQL.insert_document(%{"@type" => "Person", "name" => "Bob"}))
      assert jsonld["@type"] == "InsertDocument"
      assert jsonld["document"]["@type"] == "Value"
      assert jsonld["document"]["dictionary"]["@type"] == "DictionaryTemplate"
      fields = jsonld["document"]["dictionary"]["data"]
      assert Enum.any?(fields, &(&1["field"] == "@type"))
      assert Enum.any?(fields, &(&1["field"] == "name"))
    end

    test "insert_document/2 with identifier includes identifier field" do
      jsonld = WOQL.to_jsonld(WOQL.insert_document(%{"@type" => "Person"}, "v:Id"))
      assert jsonld["@type"] == "InsertDocument"
      assert jsonld["identifier"] == %{"@type" => "NodeValue", "variable" => "Id"}
    end

    test "update_document/1 encodes as UpdateDocument" do
      assert WOQL.to_jsonld(WOQL.update_document("v:Doc"))["@type"] == "UpdateDocument"
    end

    test "delete_document/1 encodes as DeleteDocument" do
      jsonld = WOQL.to_jsonld(WOQL.delete_document("Person/Alice"))
      assert jsonld["@type"] == "DeleteDocument"
      assert jsonld["identifier"] == %{"@type" => "NodeValue", "node" => "Person/Alice"}
    end

    test "round-trips insert_document" do
      q = WOQL.insert_document("v:Doc")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips update_document" do
      q = WOQL.update_document("v:Doc")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips delete_document" do
      q = WOQL.delete_document("Person/Alice")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "graph context" do
    test "using/2 encodes as Using" do
      jsonld = WOQL.to_jsonld(WOQL.using("mydb", WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Using"
      assert jsonld["collection"] == "mydb"
      assert jsonld["query"]["@type"] == "Triple"
    end

    test "from/2 encodes as From" do
      jsonld = WOQL.to_jsonld(WOQL.from("instance", WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "From"
      assert jsonld["graph"] == "instance"
    end

    test "into/2 encodes as Into" do
      jsonld = WOQL.to_jsonld(WOQL.into("schema", WOQL.add_triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Into"
      assert jsonld["graph"] == "schema"
    end

    test "comment/2 encodes as Comment" do
      jsonld = WOQL.to_jsonld(WOQL.comment("hello", WOQL.triple("v:S", "p", "v:O")))
      assert jsonld["@type"] == "Comment"
      assert jsonld["comment"] == %{"@type" => "xsd:string", "@value" => "hello"}
    end

    test "round-trips using" do
      q = WOQL.using("mydb", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips from" do
      q = WOQL.from("instance", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips into" do
      q = WOQL.into("schema", WOQL.add_triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips comment" do
      q = WOQL.comment("hello", WOQL.triple("v:S", "p", "v:O"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "graph meta" do
    test "size/2 encodes as Size" do
      jsonld = WOQL.to_jsonld(WOQL.size("instance", "v:Size"))
      assert jsonld["@type"] == "Size"
      assert jsonld["graph"] == "instance"
      assert jsonld["size"] == %{"@type" => "Value", "variable" => "Size"}
    end

    test "triple_count/2 encodes as TripleCount" do
      jsonld = WOQL.to_jsonld(WOQL.triple_count("instance", "v:Count"))
      assert jsonld["@type"] == "TripleCount"
      assert jsonld["graph"] == "instance"
    end

    test "round-trips size" do
      q = WOQL.size("instance", "v:Size")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips triple_count" do
      q = WOQL.triple_count("instance", "v:Count")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "round-trip: to_jsonld ∘ from_jsonld" do
    test "round-trips a triple" do
      q = WOQL.triple("v:Person", "name", "v:Name")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips an and query" do
      q = WOQL.and_([WOQL.triple("v:S", "p", "v:O"), WOQL.eq("v:O", "Alice")])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a select query" do
      q = WOQL.select(["v:Name"], WOQL.triple("v:P", "name", "v:Name"))
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips an eq query" do
      q = WOQL.eq("v:N", "Alice")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a type_of query" do
      q = WOQL.type_of("v:Person", "v:Type")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips an or query" do
      q = WOQL.or_([WOQL.eq("v:N", "Alice"), WOQL.eq("v:N", "Bob")])
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a read_document query" do
      q = WOQL.read_document("Person/Alice", "v:Doc")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end

    test "round-trips a triple with constant node object" do
      q = WOQL.triple("v:Person", "rdf:type", "@schema:Person")
      assert WOQL.from_jsonld(WOQL.to_jsonld(q)) == q
    end
  end

  describe "execute/3" do
    test "POSTs to woql/:org/:db/:repo/branch/:branch with the query as JSON-LD" do
      test = self()

      adapter =
        capture(
          test,
          Req.Response.new(status: 200, body: %{"bindings" => [%{"Name" => "Alice"}]})
        )

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      q = WOQL.select(["v:Name"], WOQL.and_([WOQL.triple("v:P", "name", "v:Name")]))

      assert {:ok, result} = WOQL.execute(config, q)

      req = last_request()
      assert req.method == :post
      assert req.url.path == "/api/woql/admin/mydb/local/branch/main"

      assert {:ok, body} = Jason.decode(req.body)
      assert body["query"]["@type"] == "Select"
      assert result["bindings"] == [%{"Name" => "Alice"}]
    end

    test "includes commit_info when :author and :message are provided" do
      test = self()
      adapter = capture(test, ok(%{"bindings" => []}))

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      WOQL.execute(config, WOQL.triple("v:S", "p", "v:O"),
        author: "admin",
        message: "write query"
      )

      req = last_request()
      assert {:ok, body} = Jason.decode(req.body)
      assert body["commit_info"]["author"] == "admin"
      assert body["commit_info"]["message"] == "write query"
    end

    test "returns {:error, _} when no database is scoped" do
      config = Config.new(endpoint: "http://localhost:6363", adapter: fn r -> {r, ok()} end)

      assert {:error, %Error{reason: :config}} =
               WOQL.execute(config, WOQL.triple("v:S", "p", "v:O"))
    end
  end

  describe "execute!/3" do
    test "returns the result on success" do
      adapter = fn req -> {req, ok(%{"bindings" => []})} end

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      assert WOQL.execute!(config, WOQL.triple("v:S", "p", "v:O")) == %{"bindings" => []}
    end

    test "raises on failure" do
      adapter = fn req -> {req, resp(400, %{"@type" => "api:bad"})} end

      config =
        Config.with_database(
          Config.new(endpoint: "http://localhost:6363", adapter: adapter),
          "mydb"
        )

      assert_raise Error, fn ->
        WOQL.execute!(config, WOQL.triple("v:S", "p", "v:O"))
      end
    end
  end
end
