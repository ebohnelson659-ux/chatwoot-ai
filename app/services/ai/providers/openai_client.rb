# app/services/ai/providers/openai_client.rb
#
# Thin provider wrapper around the ruby-openai gem.
# All LLM config lives here so swapping providers only requires a new file,
# not touching service logic.
#
module Ai
  module Providers
    class OpenaiClient
      MODEL       = 'gpt-4o-mini'.freeze  # fast + cheap; swap to gpt-4o for higher quality
      MAX_TOKENS  = 512
      TEMPERATURE = 0.4  # lower = more deterministic / professional tone

      def initialize(model: MODEL)
        @model  = model
        @client = build_client
      end

      # Sends a single user prompt and returns the assistant's text response.
      #
      # @param prompt [String]
      # @return [String, nil]
      def chat(prompt)
        response = @client.chat(
          parameters: {
            model:      @model,
            messages:   [{ role: 'user', content: prompt }],
            max_tokens: MAX_TOKENS,
            temperature: TEMPERATURE
          }
        )
        response.dig('choices', 0, 'message', 'content')&.strip
      rescue ::Faraday::Error => e
        Rails.logger.error("[Ai::Providers::OpenaiClient] Network error: #{e.message}")
        raise
      rescue StandardError => e
        Rails.logger.error("[Ai::Providers::OpenaiClient] Error: #{e.message}")
        raise
      end

      private

      def build_client
        raise '[Ai::Providers::OpenaiClient] OPENAI_API_KEY is not set' if api_key.blank?

        ::OpenAI::Client.new(access_token: api_key)
      end

      def api_key
        ENV['OPENAI_API_KEY']
      end
    end
  end
end