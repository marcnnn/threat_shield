# Loads the custom Credo checks for their tests in test/credo_checks/ and starts Credo.
# The checks are not compiled into the app or the library; Credo loads them through
# `requires` in .credo.exs.
for file <- Path.wildcard(Path.expand("support/*.ex", __DIR__)) ++
              Path.wildcard(Path.expand("*.ex", __DIR__)) do
  Code.require_file(file)
end

{:ok, _} = Application.ensure_all_started(:credo)
