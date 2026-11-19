[
  import_deps: [:ash, :ash_postgres, :ash_ai],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
