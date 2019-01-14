import Defmodulep

defmodule Lib do
  defmodulep Private, visible_to: Defmodulep do
    def add(arg1, arg2), do: arg1 + arg2

    defmodule Public do
      def multiply(arg1, arg2), do: arg1 * arg2
    end

    defmodulep Private, visible_to: [Defmodulep] do
      def multiply(arg1, arg2), do: arg1 * arg2
    end
  end

  def calls_private(arg1, arg2) do
    Private.add(arg1, arg2)
  end
end

defmodule Defmodulep.Test do
  use ExUnit.Case, async: true

  test "is visible from same context" do
    assert Lib.calls_private(1, 2) == 3
  end

  test "can require if visible" do
    requirep Lib.Private, as: Private
    assert Private.add(1, 2) == 3
  end

  test "can require twice" do
    requirep Lib.Private, as: Private
    requirep Private, as: PrivateAgain
    assert PrivateAgain.add(1, 2) == 3
  end

  test "can require from another private" do
    defmodulep AnotherPrivate do
      def calls_add(arg1, arg2) do
        requirep Lib.Private, as: Private
        Private.add(arg1, arg2)
      end
    end

    assert AnotherPrivate.calls_add(1, 2) == 3
  end

  test "cannot require if not visible" do
    assert_raise ArgumentError,
                 "cannot require private module, it is only visible to the following namespaces: [Defmodulep]",
                 fn ->
                   defmodule Elixir.NotAllowed do
                     requirep Lib.Private, as: Private
                   end
                 end
  end

  test "without visible_to" do
    defmodulep WithoutVisibleTo do
      def returns_ok, do: :ok
    end

    assert WithoutVisibleTo.returns_ok() == :ok
  end

  describe "naming" do
    name = DynamicPrivate

    defmodulep name, visible_to: [Defmodulep.Test] do
      def returns_ok, do: :ok
    end

    test "dynamic" do
      requirep DynamicPrivate, as: DynamicPrivate
      assert DynamicPrivate.returns_ok() == :ok
    end

    defmodulep Elixir.RootPrivate, visible_to: [Defmodulep.Test] do
      def returns_ok, do: :ok
    end

    test "root" do
      requirep RootPrivate, as: RootPrivate
      assert RootPrivate.returns_ok() == :ok
    end

    defmodulep :defmodulep_example, visible_to: [Defmodulep.Test] do
      def returns_ok, do: :ok
    end

    test "atom" do
      requirep :defmodulep_example, as: AtomExample
      assert AtomExample.returns_ok() == :ok
    end

    defmodulep __MODULE__.NonAtomAlias, visible_to: [Defmodulep.Test] do
      def returns_ok, do: :ok
    end

    test "non-atom alias" do
      requirep Elixir.Defmodulep.Test.NonAtomAlias, as: NonAtomAlias
      assert NonAtomAlias.returns_ok() == :ok
    end
  end

  describe "nesting" do
    @tag :skip
    test "can invoke nested public module directly" do
      assert Lib.Private.Public.multiply(1, 2) == 2
    end

    test "can invoke nested public module indirectly" do
      requirep Lib.Private, as: Private
      assert Private.Public.multiply(1, 2) == 2
    end

    test "cannot invoke nested private module directly" do
      assert_raise UndefinedFunctionError, fn -> Lib.Private.Private.multiply(1, 2) end
    end

    test "can invoke nested privatee module indirectly" do
      requirep Lib.Private, as: Private
      requirep Private.Private, as: NestedPrivate
      assert NestedPrivate.multiply(1, 2) == 2
    end
  end

  describe "internals" do
    requirep Lib.Private, as: Private

    test "aliases to string" do
      assert Atom.to_string(Private) == "modulep_028_Elixir.Lib.Private"
    end

    test "aliases to string of nested private" do
      requirep Lib.Private, as: Private
      requirep Private.Private, as: NestedPrivate
      assert Atom.to_string(NestedPrivate) == "modulep_936_Elixir.Lib.Private.Private"
    end

    @tag :skip
    test "aliases to string of concat" do
      assert Atom.to_string(Private.Public) == "Elixir.Lib.Private.Public"
      assert Atom.to_string(Private.Private) == "Elixir.Lib.Private.Private"
    end
  end

  describe "argument errors" do
    test "raises on nested private" do
      assert_raise ArgumentError,
                   ~r"cannot define multi-level private module Very\.Nested",
                   fn ->
                     defmodule WillFail do
                       defmodulep Very.Nested do
                       end
                     end
                   end
    end

    test "raises on non atom names" do
      assert_raise ArgumentError,
                   "defmodulep expected an atom as module name, got: \"bad\"",
                   fn ->
                     defmodulep "bad" do
                     end
                   end
    end

    test "raises on unknown require" do
      assert_raise ArgumentError,
                   "private module Unknown is not loaded and could not be found",
                   fn ->
                     defmodule WillFail do
                       requirep Unknown, as: Unknown
                     end
                   end
    end
  end
end
