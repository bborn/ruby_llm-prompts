require_relative "test_helper"
require "tmpdir"
require "erb"

class RenderableTest < Minitest::Test
  def test_renders_from_database
    create_prompt(slug: "test_agent/instructions", body: "Hello {{ name }}!")
    agent = build_agent("test_agent")

    result = agent.render_prompt(:instructions, name: "Bruno")
    assert_equal "Hello Bruno!", result.to_s
  end

  def test_falls_back_to_erb_file
    agent = build_agent("test_agent")

    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/prompts/test_agent"))
      File.write(File.join(dir, "app/prompts/test_agent/instructions.txt.erb"), "ERB: <%= @greeting %>")

      agent.define_singleton_method(:prompt_path) do |prompt_name|
        Pathname.new(dir).join("app/prompts/test_agent/#{prompt_name}.txt.erb")
      end
      agent.instance_variable_set(:@greeting, "Hello from ERB")

      result = agent.render_prompt(:instructions)
      assert_match(/ERB: Hello from ERB/, result)
    end
  end

  def test_raises_when_not_found_anywhere
    agent = build_agent("nonexistent_agent")

    assert_raises(RubyLLM::Prompts::PromptNotFoundError) do
      agent.render_prompt(:missing)
    end
  end

  def test_database_prompt_takes_priority_over_file
    create_prompt(slug: "test_agent/instructions", body: "DB version: {{ name }}")
    agent = build_agent("test_agent")

    # Even if a file exists, DB should win
    result = agent.render_prompt(:instructions, name: "Bruno")
    assert_equal "DB version: Bruno", result.to_s
  end

  def test_context_variables_merged
    create_prompt(slug: "test_agent/instructions", body: "{{ name }} at {{ company }}")

    agent = build_agent("test_agent")
    agent.define_singleton_method(:context_variables) { {company: "Acme"} }

    result = agent.render_prompt(:instructions, name: "Bruno")
    assert_equal "Bruno at Acme", result.to_s
  end

  private

  def build_agent(name)
    klass = Class.new do
      include RubyLLM::Prompts::Renderable

      def initialize(name)
        @name = name
      end

      private

      def agent_name
        @name
      end
    end
    klass.new(name)
  end

  def create_prompt(slug:, body:)
    RubyLLM::Prompts::Prompt.create!(slug: slug, body: body, version: 1, active: true)
  end
end
