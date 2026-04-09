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
    result = RubyLLM::Prompts.render("greet", name: "Bruno")
    assert_equal "Hi Bruno!", result.to_s
  end

  def test_render_shorthand_returns_rendered_prompt
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "Hi {{ name }}!", version: 1, active: true)
    result = RubyLLM::Prompts.render("greet", name: "Bruno")
    assert_instance_of RubyLLM::Prompts::Result, result
  end

  def test_variables_shorthand
    RubyLLM::Prompts::Prompt.create!(slug: "greet", body: "{{ name }} at {{ company }}", version: 1, active: true)
    vars = RubyLLM::Prompts.variables("greet")
    assert_includes vars, "name"
    assert_includes vars, "company"
  end

  # --- Filesystem fallback ---

  def test_render_falls_back_to_filesystem
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    result = RubyLLM::Prompts.render("greeting", name: "Bruno", company: "Acme")

    assert_instance_of RubyLLM::Prompts::Result, result
    assert_equal "Hello Bruno, welcome to Acme.", result.to_s
    assert_equal "greeting", result.slug
    assert_nil result.version
  end

  def test_render_filesystem_with_conditionals
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    result = RubyLLM::Prompts.render("conditional", name: "Bruno", brand_color: "#FF0000")

    assert_includes result.to_s, "#FF0000"
  end

  def test_render_filesystem_conditional_excludes_when_nil
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    result = RubyLLM::Prompts.render("conditional", name: "Bruno", brand_color: nil)

    refute_includes result.to_s, "Brand color"
  end

  def test_render_filesystem_nested_slug
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    result = RubyLLM::Prompts.render("nested/deep", topic: "testing")

    assert_equal "Nested prompt for testing.", result.to_s
  end

  def test_render_db_overrides_filesystem
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    RubyLLM::Prompts::Prompt.create!(slug: "greeting", body: "DB says hi {{ name }}.", version: 1, active: true)

    result = RubyLLM::Prompts.render("greeting", name: "Bruno")
    assert_equal "DB says hi Bruno.", result.to_s
    assert_equal 1, result.version
  end

  def test_render_raises_when_not_in_db_or_filesystem
    RubyLLM::Prompts.prompts_path = File.expand_path("fixtures/prompts", __dir__)
    assert_raises(RubyLLM::Prompts::PromptNotFoundError) do
      RubyLLM::Prompts.render("totally/missing")
    end
  end

  def test_render_raises_when_no_prompts_path_configured
    RubyLLM::Prompts.prompts_path = nil
    assert_raises(RubyLLM::Prompts::PromptNotFoundError) do
      RubyLLM::Prompts.render("greeting", name: "Bruno")
    end
  end
end
