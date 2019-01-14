# Defmodulep

<!-- MDOC !-->

API for defining and requiring private modules.

Private modules work by declaring exactly which other
module prefixes can access it:

```elixir
import Defmodulep

defmodulep MyApp.Private, visible_to: [MyApp] do
  def hello do
    IO.puts "hello world"
  end
end
```

In the definition above, only `MyApp` and modules nested
under it can access `MyApp.Private`.

To access a private module, you must explicitly require it
by using `requirep/2` and explicitly give it an alias:

```elixir
defmodule MyApp.Other do
  import Defmodulep
  requirep MyApp.Private, as: Private
  Private.hello
end
```

Private modules can be arbitrarily nested too:

```elixir
defmodulep MyApp.Private, visible_to: [MyApp] do
  defmodulep Nested, visible_to: [MyApp] do
    def hello do
      IO.puts "hello world"
    end
  end
end
```

Requiring `MyApp.Private` does not automatically require
`MyApp.Private.Nested`. It still need to be explicitly
required either directly:

```elixir
requirep MyApp.Private.Nested, as: Nested
```

If you have already required `Private`, you can also
require `Nested` from the `Private` alias:

```elixir
requirep MyApp.Private, as: Private
requirep Private.Nested, as: Nested
```

## Nesting

`defmodulep` works as `defmodule` as it can be accessed directly
following its definition:

```elixir
defmodule Foo do
  defmodulep Bar, visible_to: [MyApp] do
    ...
  end

  Bar # We can access bar here even if not in visible_to
end
```

In other words, a more correct description of `defmodulep`
is that it is visible to any following module declared in
the same file or to any module declared in `visible_to`.
In fact, `:visible_to` may be skipped for nested private
modules which means they are only accessible to the following
modules in the same file.

## Testing

In order to test a private module, you need to make sure
the private module is visible to the test module. Since most
private modules are visible to their own rootname, testing
just works if you follow Elixir's testing conventions.
For instance, a private module `MyApp.Foo.Bar` is likely
visible to `MyApp` or `MyApp.Foo`, which means the default
test module, which is `MyApp.Foo.BarTest`, should have access
to the private module. In other words, the following code
should work just fine:

```elixir
# lib/my_app/foo/bar.ex
defmodulep MyApp.Foo.Bar, visible_to: MyApp.Foo do
  ...
end

# test/my_app/foo/bar_test.exs
defmodule MyApp.Foo.BarTest do
  use ExUnit.Case
  ...
end
```

## Inspecting private modules

Private modules work by being assigned a different naming
structure. If you define a private module `Foo.Bar`, it will
actually be compiled as `:"modulep_DDD_Elixir.Foo.Bar"`, where
`DDD` will be a arbitrarily assigned number. The number is
arbitrary to discourage developers from accessing the underlying
module directly, as **this number may change at any time**.
The only way to safely access a private module is by calling
`requirep` first.

## Limitations

This library has the following limitations:

  * If you define `defmodulep Foo` and then `defmodule Foo`,
    this library won't warn.

  * The fact it requires an explicit `requirep` function
    is also a limitation on its own. Ideally, we would use
    Elixir's `require/2`, although that would demand changes
    to Elixir's Parallel Compiler.

  * If you invoke `SomePrivateModule.foo` without requiring
    it, the error message says the module does not exist,
    but we could do a better job and say it is actually a
    private module.

  * Private modules appear literally as `:"modulep_DDD_Elixir.Foo.Bar"`
    in stacktraces and they could enjoy a better format.

  * If you define a module `defmodule Public` nested inside
    `defmodulep Private`, `Public` cannot be accessed directly
    but only via `requirep Private, as: Private` and then by
    calling `Private.Public`. This can be fixed if we change
    `Module.concat/1` to be aware of `modulep_DDD_` prefixes.
    In other words, a `defmodule Public` inside `defmodulep`
    should remain public but it doesn't in this implementation.
    This is an important property to hold because Elixir doesn't
    really have the concept of namespaces.

All of those limitations could be addressed by adding `defmodulep`
to Elixir.

<!-- MDOC !-->

## Installation

Add `defmodulep` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:defmodulep, "~> 0.1", github: "josevalim/defmodulep"}]
end
```

## License

Copyright 2019 Plataformatec

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.