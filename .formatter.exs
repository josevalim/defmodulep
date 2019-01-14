# Used by "mix format"
locals_without_parens = [defmodulep: 2, defmodulep: 3, requirep: 2]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [locals_without_parens: locals_without_parens],
  locals_without_parens: locals_without_parens
]
