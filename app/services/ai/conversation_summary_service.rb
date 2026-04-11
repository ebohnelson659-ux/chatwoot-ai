# frozen_string_literal: true

# app/services/ai/conversation_summary_service.rb
#
# Produces a concise AI summary of a conversation thread for agents.
#
# Responsibilities:
#   1. Format the full conversation (up to char limit) via the existing LLM formatter
#   2. Build a summary-focused prompt
#   3. Delegate the LLM call to the existing provider wrapper
#
# Intentional differences from Ai::ReplyDrafterService:
#   - Larger char limit — summary needs more context than a reply draft
#   - include_private_messages: true — internal notes are useful context for a summary
#   - include_contact_details: true — contact name / channel adds clarity to the summary
#   - summary-focused prompt — bullet points, not a reply
#
# Usage:
#   summary = Ai::ConversationSummaryService.new(conversation).summarize
#   # => "The customer reported a billing discrepancy on their March invoice..."
#
module Ai
  class ConversationSummaryService
    # Larger window than reply drafter — summary benefits from seeing the full thread.
    # ~12 000 chars ≈ ~3 000 tokens, well within gpt-4o-mini's 128k context.
    CONVERSATION_CHAR_LIMIT = 12_000

    def initialize(conversation)
      @conversation = conversation
    end

    # Returns the AI-generated summary text, or nil if the provider returns nothing.
    #
    # @return [String, nil]
    def summarize
      context = format_conversation
      Ai::Providers::OpenaiClient.new.chat(build_prompt(context))
    end

    private

    # Private notes are included so the summary reflects the agent's full picture
    # of the conversation, not just the customer-visible thread.
    # Contact details give the model anchor information (name, channel) so the
    # summary reads naturally without the agent needing to remember who this is.
    def format_conversation
      LlmFormatter::ConversationLlmFormatter
        .new(@conversation)
        .format(
          token_limit: CONVERSATION_CHAR_LIMIT,
          include_private_messages: true,
          include_contact_details: true
        )
    end

    def build_prompt(context)
      <<~PROMPT
        You are an expert customer support analyst. Based on the conversation history below,
        write a concise summary for the support agent who is about to handle this conversation.

        Rules:
        - Write in plain prose — no bullet points, no headers, no markdown.
        - Cover: what the customer's issue or request is, what has been tried or discussed,
          and the current status or next expected step.
        - Keep it to 3–5 sentences maximum.
        - Write in the third person (e.g. "The customer reported...").
        - Do NOT recommend actions, give opinions, or add any text beyond the summary itself.

        --- Conversation ---
        #{context}
        --- End of conversation ---

        Summary:
      PROMPT
    end
  end
end
