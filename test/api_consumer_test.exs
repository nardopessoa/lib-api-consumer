defmodule ApiConsumerTest do
  use ExUnit.Case
  doctest ApiConsumer

  test "greets the world" do
    assert ApiConsumer.hello() == :world
  end
end
