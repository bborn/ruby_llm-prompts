# RubyLLM::Prompts

Database-backed prompt management for [RubyLLM](https://rubyllm.com). Store, version, and edit prompts without redeploying. Works transparently with RubyLLM agents and direct chat usage.

Uses [Liquid](https://shopify.github.io/liquid/) templates — sandboxed, safe for runtime editing, with a clear variable interface.

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
  body: "You are a support agent for {{ company }}. The customer is {{ name }}.",
  version: 1,
  active: true
)
```

Render it:

```ruby
RubyLLM::Prompts.render("support/system", company: "Acme", name: "Bruno")
# => "You are a support agent for Acme. The customer is Bruno."
```

Use it with RubyLLM:

```ruby
prompt = RubyLLM::Prompts.render("support/system", company: "Acme", name: "Bruno")
chat = RubyLLM.chat
chat.with_instructions(prompt)
chat.ask("I can't log in")
```

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
body: |
  You are a support agent for {{ company }}.
  The customer is {{ name }}.
metadata:
  description: "Customer support system prompt"
```

Seed is idempotent — only creates a new version when the body or metadata changes:

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
- Create and edit prompts
- View version history
- Roll back to previous versions

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
RubyLLM::Prompts.render(slug, variables)       # find + render in one call
RubyLLM::Prompts.variables(slug)               # list expected variables
RubyLLM::Prompts.seed!(path: "db/prompts")     # upsert from YAML files

prompt.render(variables)                        # render with Liquid
prompt.expected_variables                       # introspect template variables
prompt.new_version!(body: "...", metadata: ...) # create new version
prompt.rollback!                                # restore previous version
```

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
