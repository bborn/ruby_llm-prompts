# frozen_string_literal: true

module RubyLLM
  module Prompts
    # Wraps a rendered prompt with metadata and structured output.
    # Behaves like a String (via to_s and implicit coercion) so existing
    # code that passes render results to chat.ask or with_instructions
    # keeps working unchanged.
    #
    #   result = RubyLLM::Prompts.render("support/system", name: "Bruno")
    #   result.to_s            # => "You are a support agent..."
    #   result.system_message  # => "You are helpful." (or nil)
    #   result.messages        # => [{ role: "system", content: "..." }, { role: "user", content: "..." }]
    #   result.slug            # => "support/system"
    #   result.version         # => 2
    #
    class Result
      attr_reader :body, :system_message, :slug, :version, :metadata

      def initialize(body:, system_message: nil, slug: nil, version: nil, metadata: nil)
        @body = body
        @system_message = system_message
        @slug = slug
        @version = version
        @metadata = metadata
      end

      # Chat-format messages array.
      # Includes a system message when present, plus the rendered body as user content.
      def messages
        msgs = []
        msgs << {role: "system", content: system_message} if system_message.present?
        msgs << {role: "user", content: body}
        msgs
      end

      # Hash representation for serialization or logging.
      def to_h
        {
          slug: slug,
          version: version,
          body: body,
          system_message: system_message,
          messages: messages,
          metadata: metadata
        }
      end

      # Implicit string coercion — makes Result work anywhere a String does.
      # chat.ask(result) and with_instructions(result) just work.
      def to_s
        body
      end

      def to_str
        body
      end

      def ==(other)
        case other
        when Result then body == other.body && system_message == other.system_message
        when String then body == other
        else false
        end
      end
    end
  end
end
