require_relative "test_helper"

class PromptsTest < Minitest::Test
  def test_get_returns_active_prompt
    RubyLLM::Prompts::Prompt.create!(slug: "a/b", body: "old", version: 1, active: false)
    RubyLLM::Prompts::Prompt.create!(slug: "a/b", body: "new", version: 2, active: true)

    prompt = RubyLLM::Prompts.get("a/b")
    assert_equal "new", prompt.body
    assert_equal 2, prompt.version
  end

  def test_get_raises_when_not_found
    assert_raises(RubyLLM::Prompts::PromptNotFoundError) do
      RubyLLM::Prompts.get("nonexistent")
    end
  end

  def test_render_shorthand
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "Hi {{ name }}!", version: 1, active: true)
    assert_equal "Hi Bruno!", RubyLLM::Prompts.render("greet", name: "Bruno")
  end

  def test_variables_shorthand
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "{{ name }} at {{ company }}", version: 1, active: true)
    vars = RubyLLM::Prompts.variables("greet")
    assert_includes vars, "name"
    assert_includes vars, "company"
  end
end
