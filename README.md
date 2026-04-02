# RubyLLM::Prompts

Database-backed prompt management for [RubyLLM](https://rubyllm.com). Store, version, and edit prompts without redeploying. Works transparently with RubyLLM agents and direct chat usage.

Uses [Liquid2](https://github.com/jg-rp/ruby-liquid2) templates — sandboxed, safe for runtime editing, with proper static analysis of template variables.

## Installation

Add to your Gemfile:

```ruby
gem "ruby_llm-prompts"
```

Run the install generator:

```sh
rails generate ruby_llm:prompts:install
rails db:migrate
```

Mount the admin UI:

```ruby
# config/routes.rb
mount RubyLLM::Prompts::Engine, at: "/prompts"
```

## Quick Start

Create a prompt:

```ruby
RubyLLM::Prompts::Prompt.create!(
  slug: "support/system",
  system_message: "You are a support agent for {{ company }}.",
  body: "The customer is {{ name }}. Help them with their issue.",
  version: 1,
  active: true
)
```

Render it:

```ruby
rendered = RubyLLM::Prompts.render("support/system", company: "Acme", name: "Bruno")
rendered.to_s            # => "The customer is Bruno. Help them with their issue."
rendered.system_message  # => "You are a support agent for Acme."
rendered.messages        # => [{ role: "system", content: "You are..." }, { role: "user", content: "The customer..." }]
```

Use it with RubyLLM:

```ruby
rendered = RubyLLM::Prompts.render("support/system", company: "Acme", name: "Bruno")
chat = RubyLLM.chat
chat.with_instructions(rendered.system_message)
chat.ask(rendered)  # Result coerces to string automatically
```

## Result

`render` returns a `Result` object, not a plain string. It behaves like a string (via `to_s`/`to_str`) so existing code keeps working, but also provides structured access:

```ruby
rendered = RubyLLM::Prompts.render("support/system", name: "Bruno")

rendered.to_s            # the rendered body as a string
rendered.body            # same as to_s
rendered.system_message  # rendered system message, or nil
rendered.messages        # [{ role: "system", content: "..." }, { role: "user", content: "..." }]
rendered.slug            # "support/system"
rendered.version         # 2
rendered.metadata        # { "author" => "bruno" }
rendered.to_h            # everything as a hash
```

String coercion means `Result` works anywhere a string does:

```ruby
chat.ask(rendered)                   # works — to_str kicks in
"Prompt: #{rendered}"                # works — interpolation
rendered == "expected output"        # works — equality with strings
```

## System Messages

Prompts can have a separate `system_message` for system/user separation:

```ruby
RubyLLM::Prompts::Prompt.create!(
  slug: "assistant",
  system_message: "You are a {{ role }}. Be concise.",
  body: "Help {{ user_name }} with their request.",
  version: 1,
  active: true
)
```

Both `system_message` and `body` support Liquid templates with the same variables. Variables are extracted from both fields:

```ruby
prompt = RubyLLM::Prompts.get("assistant")
prompt.expected_variables  # => ["role", "user_name"]
```

The `system_message` is optional — prompts without one work exactly as before.

## Liquid Templates

Prompts use Liquid syntax. Variables are `{{ name }}`, conditionals are `{% if flag %}...{% endif %}`.

```
You are a helpful assistant for {{ user_name }}.
Today is {{ current_date }}.

{% if vip %}
This is a VIP customer. Prioritize their request.
{% endif %}
```

Empty strings, `"false"`, `nil`, and `false` are all falsy in conditionals. `"true"` and `true` are truthy. This is handled automatically — no surprises from string coercion.

## Introspect Variables

`expected_variables` uses Liquid2's static analysis to extract only the variables your template actually needs — `{% assign %}` locals and `{% for %}` loop variables are automatically excluded.

```ruby
prompt = RubyLLM::Prompts.get("support/system")
prompt.expected_variables
# => ["company", "name", "vip"]
```

Strict mode (default) raises `UndefinedVariableError` when a variable is missing:

```ruby
RubyLLM::Prompts.render("support/system", company: "Acme")
# => RubyLLM::Prompts::UndefinedVariableError: undefined variable name ...
```

Disable strict mode for lenient rendering:

```ruby
RubyLLM::Prompts.strict_variables = false
```

## Versioning

Every edit creates a new version. Only one version is active per slug.

```ruby
prompt = RubyLLM::Prompts.get("support/system")
prompt.new_version!(body: "Updated prompt text...")
# => #<Prompt slug: "support/system", version: 2, active: true>
```

Roll back:

```ruby
prompt = RubyLLM::Prompts.get("support/system")
prompt.rollback!
# => #<Prompt slug: "support/system", version: 1, active: true>
```

## Seed Files

Store prompts as YAML files in `db/prompts/` and deploy them with your code:

```yaml
# db/prompts/support/system.yml
slug: support/system
system_message: |
  You are a support agent for {{ company }}.
body: |
  The customer is {{ name }}. Help them with their issue.
metadata:
  description: "Customer support system prompt"
```

Seed is idempotent — only creates a new version when the body, system_message, or metadata changes:

```ruby
RubyLLM::Prompts.seed!
```

The install generator adds `RubyLLM::Prompts.seed!` to `db/seeds.rb`.

## RubyLLM Agent Integration

If you use [RubyLLM agents](https://rubyllm.com/agents/), the gem hooks in automatically. When an agent renders a prompt, it checks the database first and falls back to the filesystem.

```ruby
class SupportAgent < RubyLLM::Agent
  instructions company: -> { chat.company.name }
end
```

If a prompt with slug `support_agent/instructions` exists in the database, it's used (rendered with Liquid). Otherwise, the agent loads `app/prompts/support_agent/instructions.txt.erb` as usual.

No code changes needed in your agents.

### Custom Agent Classes

For agents that don't inherit from `RubyLLM::Agent`, include `Renderable`:

```ruby
class ApplicationAgent
  include RubyLLM::Prompts::Renderable

  def initialize(tenant:)
    @tenant = tenant
  end

  def chat(prompt_name = :instructions)
    prompt = render_prompt(prompt_name, tenant_name: @tenant.name)
    RubyLLM.chat.ask(prompt)
  end
end
```

`render_prompt` checks the database first, falls back to `app/prompts/{agent_name}/{prompt_name}.txt.erb`.

## Admin UI

Mount the engine and visit `/prompts` to:

- Browse all prompts with their variables
- Create and edit prompts (body + system message)
- View version history with diffs between versions
- Roll back to previous versions
- **Playground** — test prompts with sample variables and see the rendered output, system message, and messages array

### Authentication

The admin UI has no built-in authentication. Protect it with route constraints:

```ruby
# Devise
authenticate :user, ->(u) { u.admin? } do
  mount RubyLLM::Prompts::Engine, at: "/prompts"
end

# Basic auth
mount RubyLLM::Prompts::Engine, at: "/prompts",
  constraints: ->(req) { req.env["warden"]&.user&.admin? }
```

## Upgrade Path

Designed for gradual adoption:

1. **Day 1** — Add the gem, run the generator, migrate. Everything still uses your existing ERB files. Zero behavior change.
2. **Day 2** — Move one prompt to the database (via admin UI or seed file). That prompt now uses Liquid from the DB. Everything else stays on ERB files.
3. **Gradually** — Migrate prompts as needed. Database always takes priority over filesystem.

The slug convention (`agent_name/prompt_name`) maps 1:1 to the filesystem convention (`app/prompts/agent_name/prompt_name.txt.erb`).

## Configuration

```ruby
# config/initializers/ruby_llm_prompts.rb
RubyLLM::Prompts.strict_variables = true   # raise on missing variables (default: true)
RubyLLM::Prompts.prompts_path = "db/prompts" # seed file directory (default: "db/prompts")
```

## API Reference

```ruby
RubyLLM::Prompts.get(slug)                    # find active prompt, raises PromptNotFoundError
RubyLLM::Prompts.render(slug, variables)       # find + render, returns Result
RubyLLM::Prompts.variables(slug)               # list expected variables
RubyLLM::Prompts.seed!(path: "db/prompts")     # upsert from YAML files

prompt.render(variables)                        # render with Liquid, returns Result
prompt.expected_variables                       # introspect template variables (body + system_message)
prompt.new_version!(body: "...", system_message: "...", metadata: ...)
prompt.rollback!                                # restore previous version

rendered.to_s / rendered.body                   # rendered body text
rendered.system_message                         # rendered system message (or nil)
rendered.messages                               # [{ role: "system", content: "..." }, { role: "user", content: "..." }]
rendered.to_h                                   # full hash with slug, version, messages, metadata
rendered.slug / rendered.version / rendered.metadata
```

## Tracking Usage

Every render emits a `render_prompt.ruby_llm_prompts` notification with `slug`, `version`, and `metadata`. Subscribe to connect prompts to whatever tracking you use:

```ruby
ActiveSupport::Notifications.subscribe("render_prompt.ruby_llm_prompts") do |*, payload|
  # payload[:slug]     => "support/system"
  # payload[:version]  => 2
  # payload[:metadata] => {"author" => "bruno"}
end
```

This works for both direct `render` calls and transparent agent integration.

## Auditing

The gem does not include audit logging. Add [PaperTrail](https://github.com/paper-trail-gem/paper_trail) to the `Prompt` model if you need change tracking:

```ruby
# config/initializers/ruby_llm_prompts.rb
Rails.application.config.after_initialize do
  RubyLLM::Prompts::Prompt.has_paper_trail
end
```

## License

MIT
