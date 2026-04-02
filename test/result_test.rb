require_relative "test_helper"

class ResultTest < Minitest::Test
  def test_to_s_returns_body
    result = build_result(body: "Hello Bruno")
    assert_equal "Hello Bruno", result.to_s
  end

  def test_to_str_enables_implicit_coercion
    result = build_result(body: "Hello")
    # String interpolation and methods expecting strings should work via to_str
    assert_equal "Say: Hello", "Say: #{result}"
  end

  def test_messages_without_system
    result = build_result(body: "Hello")
    expected = [{role: "user", content: "Hello"}]
    assert_equal expected, result.messages
  end

  def test_messages_with_system
    result = build_result(body: "Hello", system_message: "Be helpful.")
    expected = [
      {role: "system", content: "Be helpful."},
      {role: "user", content: "Hello"}
    ]
    assert_equal expected, result.messages
  end

  def test_to_h
    result = build_result(
      body: "Hello",
      system_message: "Be nice.",
      slug: "test/one",
      version: 3,
      metadata: {"author" => "bruno"}
    )
    hash = result.to_h

    assert_equal "test/one", hash[:slug]
    assert_equal 3, hash[:version]
    assert_equal "Hello", hash[:body]
    assert_equal "Be nice.", hash[:system_message]
    assert_equal({"author" => "bruno"}, hash[:metadata])
    assert_equal 2, hash[:messages].size
  end

  def test_equality_with_string
    result = build_result(body: "Hello")
    assert_equal "Hello", result
  end

  def test_equality_with_result
    a = build_result(body: "Hello", system_message: "Sys")
    b = build_result(body: "Hello", system_message: "Sys")
    assert_equal a, b
  end

  def test_inequality_when_body_differs
    a = build_result(body: "Hello")
    b = build_result(body: "Goodbye")
    refute_equal a, b
  end

  def test_inequality_when_system_differs
    a = build_result(body: "Hello", system_message: "A")
    b = build_result(body: "Hello", system_message: "B")
    refute_equal a, b
  end

  private

  def build_result(body:, system_message: nil, slug: "test/one", version: 1, metadata: nil)
    RubyLLM::Prompts::Result.new(
      body: body,
      system_message: system_message,
      slug: slug,
      version: version,
      metadata: metadata
    )
  end
end
