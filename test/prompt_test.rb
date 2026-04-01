require_relative "test_helper"

class PromptTest < Minitest::Test
  def test_render_with_variables
    prompt = create_prompt(body: "Hello {{ name }}, welcome to {{ company }}.")
    result = prompt.render(name: "Bruno", company: "Acme")
    assert_equal "Hello Bruno, welcome to Acme.", result
  end

  def test_render_strict_raises_on_missing_variable
    prompt = create_prompt(body: "Hello {{ name }}.")
    error = assert_raises(RubyLLM::Prompts::UndefinedVariableError) do
      prompt.render({})
    end
    assert_match(/name/, error.message)
  end

  def test_render_lenient_mode
    RubyLLM::Prompts.strict_variables = false
    prompt = create_prompt(body: "Hello {{ name }}.")
    result = prompt.render({})
    assert_equal "Hello .", result
  end

  def test_expected_variables
    prompt = create_prompt(body: "{{ first_name }} {{ last_name }} {% if vip %}VIP{% endif %}")
    assert_includes prompt.expected_variables, "first_name"
    assert_includes prompt.expected_variables, "last_name"
    assert_includes prompt.expected_variables, "vip"
  end

  def test_expected_variables_excludes_liquid_keywords
    prompt = create_prompt(body: "{% if active %}yes{% endif %}")
    refute_includes prompt.expected_variables, "if"
    refute_includes prompt.expected_variables, "endif"
  end

  def test_new_version
    prompt = create_prompt(body: "v1 body")
    v2 = prompt.new_version!(body: "v2 body")

    assert_equal 2, v2.version
    assert v2.active?
    refute prompt.reload.active?
  end

  def test_new_version_increments_from_max
    prompt = create_prompt(body: "v1")
    v2 = prompt.new_version!(body: "v2")
    v3 = v2.new_version!(body: "v3")

    assert_equal 3, v3.version
  end

  def test_rollback
    v1 = create_prompt(body: "v1")
    v2 = v1.new_version!(body: "v2")

    rolled_back = v2.rollback!
    assert_equal 1, rolled_back.version
    assert rolled_back.active?
    refute v2.reload.active?
  end

  def test_rollback_with_no_previous_version
    prompt = create_prompt(body: "v1")
    assert_raises(RubyLLM::Prompts::Error) do
      prompt.rollback!
    end
  end

  def test_boolean_true_string_is_truthy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "VIP", prompt.render(vip: "true")
  end

  def test_boolean_false_string_is_falsy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "", prompt.render(vip: "false")
  end

  def test_boolean_true_value_is_truthy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "VIP", prompt.render(vip: true)
  end

  def test_boolean_false_value_is_falsy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "", prompt.render(vip: false)
  end

  def test_empty_string_is_falsy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "", prompt.render(vip: "")
  end

  def test_nil_is_falsy
    prompt = create_prompt(body: "{% if vip %}VIP{% endif %}")
    assert_equal "", prompt.render(vip: nil)
  end

  def test_render_emits_notification
    prompt = create_prompt(slug: "notify/test", body: "Hello {{ name }}")
    events = []

    callback = lambda { |*, payload| events << payload }
    ActiveSupport::Notifications.subscribe("render_prompt.ruby_llm_prompts", callback)

    prompt.render(name: "Bruno")

    assert_equal 1, events.size
    assert_equal "notify/test", events.first[:slug]
    assert_equal 1, events.first[:version]
  ensure
    ActiveSupport::Notifications.unsubscribe(callback)
  end

  def test_render_notification_not_emitted_on_error
    prompt = create_prompt(body: "{{ name }}")
    events = []

    callback = lambda { |*, payload| events << payload }
    ActiveSupport::Notifications.subscribe("render_prompt.ruby_llm_prompts", callback)

    assert_raises(RubyLLM::Prompts::UndefinedVariableError) { prompt.render({}) }
    assert_empty events
  ensure
    ActiveSupport::Notifications.unsubscribe(callback)
  end

  def test_version_uniqueness
    create_prompt(slug: "test/prompt", body: "v1", version: 1)
    assert_raises(ActiveRecord::RecordInvalid) do
      RubyLLM::Prompts::Prompt.create!(slug: "test/prompt", body: "dupe", version: 1)
    end
  end

  private

  def create_prompt(slug: "test/instructions", body: "Hello", version: 1, active: true, metadata: nil)
    RubyLLM::Prompts::Prompt.create!(
      slug: slug,
      body: body,
      version: version,
      active: active,
      metadata: metadata
    )
  end
end
