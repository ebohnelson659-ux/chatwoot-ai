# app/services/ai/providers/grok_client.rb
#
# Thin provider wrapper around Grok (xAI) API.
# Uses OpenAI-compatible interface with a different base URL.
#
module Ai
  module Providers
    class GrokClient
      MODEL       = 'grok-2-latest'.freeze
      MAX_TOKENS  = 512
      TEMPERATURE = 0.4

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
            model: @model,
            messages: [
              { role: 'user', content: prompt }
            ],
            max_tokens: MAX_TOKENS,
            temperature: TEMPERATURE
          }
        )

        response.dig('choices', 0, 'message', 'content')&.strip
      rescue ::Faraday::Error => e
        Rails.logger.error("[Ai::Providers::GrokClient] Network error: #{e.message}")
        raise
      rescue StandardError => e
        Rails.logger.error("[Ai::Providers::GrokClient] Error: #{e.message}")
        raise
      end

      private

      def build_client
        raise '[Ai::Providers::GrokClient] GROK_API_KEY is not set' if api_key.blank?

        ::OpenAI::Client.new(
          access_token: api_key,
          uri_base: "https://api.x.ai/v1" # 👈 THIS is the key change
        )
      end

      def api_key
        ENV['GROK_API_KEY']
      end
    end
  end
end