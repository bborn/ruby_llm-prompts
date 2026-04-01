require_relative "test_helper"
require "tmpdir"
require "fileutils"

class SeedTest < Minitest::Test
  def test_seed_creates_prompts
    with_prompt_files("greet" => {slug: "greet", body: "Hello {{ name }}"}) do |dir|
      count = RubyLLM::Prompts.seed!(path: dir)
      assert_equal 1, count

      prompt = RubyLLM::Prompts.get("greet")
      assert_equal "Hello {{ name }}", prompt.body
    end
  end

  def test_seed_updates_changed_prompts
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "Old body", version: 1, active: true)

    with_prompt_files("greet" => {slug: "greet", body: "New body"}) do |dir|
      count = RubyLLM::Prompts.seed!(path: dir)
      assert_equal 1, count

      prompt = RubyLLM::Prompts.get("greet")
      assert_equal "New body", prompt.body
      assert_equal 2, prompt.version
    end
  end

  def test_seed_skips_unchanged_prompts
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "Same body", version: 1, active: true)

    with_prompt_files("greet" => {slug: "greet", body: "Same body"}) do |dir|
      count = RubyLLM::Prompts.seed!(path: dir)
      assert_equal 0, count
    end
  end

  def test_seed_raises_on_missing_directory
    assert_raises(RubyLLM::Prompts::Error) do
      RubyLLM::Prompts.seed!(path: "/nonexistent/path")
    end
  end

  private

  def with_prompt_files(prompts)
    Dir.mktmpdir do |dir|
      prompts.each do |name, data|
        file_path = File.join(dir, "#{name}.yml")
        FileUtils.mkdir_p(File.dirname(file_path))
        File.write(file_path, {
          "slug" => data[:slug],
          "body" => data[:body],
          "metadata" => data[:metadata]
        }.compact.to_yaml)
      end
      yield Pathname.new(dir)
    end
  end
end
