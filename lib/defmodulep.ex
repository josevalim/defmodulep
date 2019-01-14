defmodule Defmodulep do
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @doc """
  Defines a private module.

  ## Options

    * `:visible_to` - an atom or a list of atoms the module
      is visible to

  """
  defmacro defmodulep(alias, opts \\ [], do_block) do
    opts = Keyword.merge(opts, do_block)
    block = Keyword.fetch!(opts, :do)
    visible_to = Keyword.get(opts, :visible_to)

    env = __CALLER__
    expanded = Macro.expand(alias, env)

    {expanded, with_alias} =
      case is_atom(expanded) do
        true ->
          {old, new} = expand_private(alias, expanded, env.module)
          meta = [defined: old, context: env.module] ++ alias_meta(alias)
          {old, {:alias, meta, [old, [as: new, warn: false]]}}

        false ->
          expr = quote do: Elixir.Defmodulep.__private__!(unquote(expanded))
          {expr, nil}
      end

    meta =
      quote unquote: false do
        @doc false
        def __defmodulep__(:visible_to), do: unquote(visible_to)
      end

    quote do
      visible_to = Elixir.Defmodulep.__visible_to__!(unquote(visible_to), __ENV__.module)
      unquote(with_alias)

      defmodule unquote(expanded) do
        @before_compile Defmodulep
        unquote(meta)
        unquote(block)
      end
    end
  end

  defp alias_meta({:__aliases__, meta, _}), do: meta
  defp alias_meta(_), do: []

  # defmodulep Elixir.Alias
  defp expand_private({:__aliases__, _, [:"Elixir", _ | _]}, module, _env),
    do: {private_name(Atom.to_string(module)), nil}

  # defmodulep Alias nested
  defp expand_private({:__aliases__, _, [head]} = alias, _, env_module) when env_module != nil,
    do: {private_name("#{env_module}.#{head}"), alias}

  # defmodulep Alias.Other
  defp expand_private({:__aliases__, _, [_ | _]} = alias, _, env_module) when env_module != nil do
    raise ArgumentError, """
    cannot define multi-level private module #{Macro.to_string(alias)} nested in another module.

    For example, the following is not allowed:

        defmodule MyApp do
          defmodulep Two.Entries do
            ...
          end
        end

    If renaming is an option, you can consider:

        defmodule MyApp do
          defmodulep TwoEntries do
            ...
          end
        end

    Or write it using the full namespace without nesting:

        defmodulep MyApp.Two.Entries do
          ...
        end
    """
  end

  defp expand_private(_, module, _) do
    {private_name(Atom.to_string(module)), nil}
  end

  @doc """
  Requires a private module.

  The `as: as` option is always required.

      requirep SomePrivateModule, as: SomePrivateModule

  """
  defmacro requirep(alias, as: as) do
    expanded = Macro.expand(alias, __CALLER__)

    unless is_atom(expanded) do
      raise ArgumentError, "requirep expects an alias that expands to an atom at compile time"
    end

    # TODO: This is a workaround because Module.concat/2 does not know about modulep
    expanded =
      case Atom.to_string(expanded) do
        "Elixir.modulep_" <> rest -> :"modulep_#{rest}"
        _ -> expanded
      end

    mod = __CALLER__.module |> Atom.to_string() |> remove_private_prefix()
    private = expanded |> Atom.to_string() |> private_name()

    unless Code.ensure_compiled?(private) do
      raise ArgumentError,
            "private module #{inspect(expanded)} is not loaded and could not be found"
    end

    visible_to = private.__defmodulep__(:visible_to)

    unless Enum.any?(visible_to, &visible_to?(mod, &1)) do
      raise ArgumentError,
            "cannot require private module, it is only visible to the following namespaces: " <>
              inspect(Enum.map(visible_to, &String.to_atom/1))
    end

    quote do
      require unquote(private), as: unquote(as)
    end
  end

  defp visible_to?(mod, mod), do: true

  defp visible_to?(mod, prefix) do
    size = byte_size(prefix)
    match?(<<mod_prefix::binary-size(size), ?., _::binary>> when mod_prefix == prefix, mod)
  end

  @doc false
  def __private__!(expanded) do
    unless is_atom(expanded) do
      raise ArgumentError, "defmodulep expected an atom as module name, got: #{inspect(expanded)}"
    end

    private_name(Atom.to_string(expanded))
  end

  @doc false
  def __visible_to__!(visible_to, nesting) do
    visible_to = List.wrap(visible_to)

    if visible_to == [] and is_nil(nesting) do
      raise ArgumentError, ":visible_to must be given when defmodulep is not nested"
    end

    unless Enum.all?(visible_to, &is_atom/1) do
      raise ArgumentError, ":visible_to must be an atom or a non-empty list of atoms"
    end

    Enum.map(visible_to, &Atom.to_string/1)
  end

  @doc false
  def __before_compile__(%{module: module, line: line} = env) do
    case Module.get_attribute(module, :moduledoc) do
      nil ->
        :ok

      {_, false} ->
        :ok

      _ ->
        IO.warn(
          "warning: @moduledoc is always discarded for defmodulep",
          Macro.Env.stacktrace(env)
        )
    end

    Module.put_attribute(module, :moduledoc, {line, false})
  end

  defp private_name(string) when is_binary(string) do
    module = remove_private_prefix(string)
    :"modulep_#{hash(module)}_#{module}"
  end

  defp remove_private_prefix(<<"modulep_", _, _, _, "_", rest::binary>>), do: rest
  defp remove_private_prefix(rest), do: rest

  defp hash(expanded) when is_binary(expanded) do
    case :erlang.phash2(expanded, 1000) do
      number when number < 10 -> <<?0, ?0>> <> Integer.to_string(number)
      number when number < 100 -> <<?0>> <> Integer.to_string(number)
      number when number < 1000 -> Integer.to_string(number)
    end
  end
end
