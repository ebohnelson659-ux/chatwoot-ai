# app/services/ai/reply_drafter_service.rb
#
# Builds a prompt from recent conversation history and returns an AI-drafted
# reply. Keep this class focused: format context → build prompt → call provider.
#
module Ai
  class ReplyDrafterService
    # ~6 000 chars ≈ ~1 500 tokens — enough for recent messages, well under GPT limits.
    CONVERSATION_CHAR_LIMIT = 6_000

    def initialize(conversation)
      @conversation = conversation
    end

    # @return [String, nil] the drafted reply text, or nil if the provider returns nothing
    def draft
      context = format_conversation
      Ai::Providers::OpenaiClient.new.chat(build_prompt(context))
    end

    private

    # Delegates formatting to the existing LLM formatter.
    # token_limit keeps the context bounded; we skip private notes so internal
    # team chatter does not leak into the customer-facing draft.
    def format_conversation
      LlmFormatter::ConversationLlmFormatter
        .new(@conversation)
        .format(
          token_limit: CONVERSATION_CHAR_LIMIT,
          include_private_messages: false,
          include_contact_details: false
        )
    end

    def build_prompt(context)
      <<~PROMPT
        You are an expert customer support agent. Based on the conversation history below,
        write a professional, concise, and empathetic reply to the most recent customer message.

        Rules:
        - Address the customer's latest concern directly.
        - Match the tone already set by the support agent in the conversation.
        - Do NOT add a subject line, greeting, or sign-off unless the conversation clearly uses them.
        - Return ONLY the reply text — no labels, no explanations, no markdown.

        --- Conversation ---
        #{context}
        --- End of conversation ---

        Agent reply:
      PROMPT
    end
  end
end