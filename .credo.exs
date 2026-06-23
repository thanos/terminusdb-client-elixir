# .credo.exs — strict configuration for terminusdb_ex
%{
  configs: [
    %{
      name: "default",
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Consistency.TabsOrSpaces},
        {Credo.Check.Consistency.SpaceAroundOperators},
        {Credo.Check.Readability.MaxLineLength, max_length: 98},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.ModuleNames, false},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.TrailingWhiteSpace},
        {Credo.Check.Readability.TrailingBlankLine},
        {Credo.Check.Readability.SinglePipe},
        {Credo.Check.Readability.AliasOrder},
        {Credo.Check.Refactor.DoubleBooleanNegation},
        {Credo.Check.Refactor.CaseTrivialMatches},
        {Credo.Check.Refactor.CondStatements},
        {Credo.Check.Refactor.FunctionArity, max_arity: 8},
        {Credo.Check.Refactor.MatchInCondition},
        {Credo.Check.Refactor.Nesting, max_nesting: 4},
        {Credo.Check.Warning.IoInspect},
        {Credo.Check.Warning.IExPry},
        {Credo.Check.Warning.OperationOnSameValues},
        {Credo.Check.Warning.BoolOperationOnSameValues},
        {Credo.Check.Warning.UnusedEnumOperation},
        {Credo.Check.Warning.UnusedKeywordOperation},
        {Credo.Check.Warning.UnusedListOperation},
        {Credo.Check.Warning.UnusedStringOperation},
        {Credo.Check.Warning.UnusedTupleOperation}
      ]
    }
  ]
}
