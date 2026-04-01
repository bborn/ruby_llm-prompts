class PlaygroundController < ApplicationController
  def index
    @prompts = RubyLLM::Prompts::Prompt.active.order(:slug)
  end

  def show
    @prompt = RubyLLM::Prompts::Prompt.active.find_by!(slug: params[:slug])
    @variables = @prompt.expected_variables
    @values = {}
    @variables.each { |v| @values[v] = params[v] || "" }
  end

  def run
    @prompt = RubyLLM::Prompts::Prompt.active.find_by!(slug: params[:slug])
    @variables = @prompt.expected_variables
    @values = params.permit(*@variables).to_h

    @rendered = @prompt.render(@values)

    @user_message = params[:user_message].presence || "Hello!"

    chat = RubyLLM.chat
    chat.with_instructions(@rendered)
    @response = chat.ask(@user_message)
  end
end
