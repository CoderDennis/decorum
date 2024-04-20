defmodule ReadmeTest do
  use ExUnit.Case, async: true

  test "version in readme matches mix.exs" do
    readme_markdown = File.read!(Path.join(__DIR__, "../README.md"))
    mix_config = Mix.Project.config()
    version = mix_config[:version]
    assert readme_markdown =~ ~s({:decorum, "~> #{version}", only: :test})
  end
end
