# frozen_string_literal: true

module RubyLLM
  module Prompts
    class PromptsController < ApplicationController
      before_action :set_prompt, only: [:show, :edit, :update, :versions, :rollback, :playground, :execute_playground]

      def index
        @prompts = Prompt.active.order(:slug)
      end

      def show
      end

      def new
        @prompt = Prompt.new
      end

      def create
        @prompt = Prompt.new(prompt_params.merge(version: 1, active: true))
        if @prompt.save
          redirect_to prompt_path(@prompt.slug), notice: "Prompt created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        new_version = @prompt.new_version!(
          body: prompt_params[:body],
          system_message: prompt_params[:system_message],
          metadata: prompt_params[:metadata]
        )
        redirect_to prompt_path(new_version.slug), notice: "Prompt updated (v#{new_version.version})."
      end

      def versions
        @versions = Prompt.where(slug: @prompt.slug).order(version: :desc)
      end

      def rollback
        previous = @prompt.rollback!
        redirect_to prompt_path(previous.slug), notice: "Rolled back to v#{previous.version}."
      rescue RubyLLM::Prompts::Error => e
        redirect_to versions_prompt_path(@prompt.slug), alert: e.message
      end

      def playground
        @variables = @prompt.variables
        @result = nil
      end

      def execute_playground
        @variables = @prompt.variables
        variable_values = params[:variables]&.to_unsafe_h || {}
        @result = @prompt.render(variable_values)
      rescue RubyLLM::Prompts::UndefinedVariableError => e
        @error = e.message
      ensure
        render :playground
      end

      private

      def set_prompt
        @prompt = Prompt.active.find_by!(slug: params[:slug])
      rescue ActiveRecord::RecordNotFound
        redirect_to root_path, alert: "Prompt not found."
      end

      def prompt_params
        params.require(:prompt).permit(:slug, :body, :system_message, :metadata)
      end
    end
  end
end
