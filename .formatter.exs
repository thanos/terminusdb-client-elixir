# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 98,
  import_deps: [:telemetry],
  locals_without_parens: [
    # Reserved for future WOQL DSL macros/imports
  ]
]
