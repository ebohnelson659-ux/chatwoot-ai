# frozen_string_literal: true

# app/services/ai/reply_rewriter_service.rb
#
# Rewrites a draft reply into a requested style using the existing provider wrapper.
#
# Responsibilities:
#   1. Validate the requested mode against the allow-list
#   2. Build a mode-specific rewrite prompt
#   3. Delegate the LLM call to Ai::Providers::OpenaiClient
#   4. Return the rewritten text, or raise on failure
#
# Design notes:
#   - No conversation context is needed — the agent's draft is the only input.
#     This keeps the service fast and the prompt focused.
#   - The mode allow-list is the single source of truth. The controller and
#     frontend both reference the same four values: professional, friendly,
#     shorter, clearer.
#   - Prompts are inline strings (not Liquid templates) to avoid the Captain/
#     Liquid dependency. This service lives in app/services/ai/, not lib/captain/.
#   - The existing Captain::RewriteService covers different modes (casual,
#     confident, straightforward) and a different call path. This service is
#     intentionally separate and does not replace it.
#
# Usage:
#   result = Ai::ReplyRewriterService.new(content: "...", mode: "friendly").rewrite
#   # => "Thanks so much for reaching out! I'd be happy to help..."
#
module Ai
  class ReplyRewriterService
    MODES = %w[professional friendly shorter clearer].freeze

    def initialize(content:, mode:)
      @content = content.to_s.strip
      @mode = mode.to_s
    end

    # @return [String] the rewritten reply text
    # @raise [ArgumentError] if mode is not in the allow-list or content is blank
    # @raise [StandardError] bubbled up from the provider on network/API failure
    def rewrite
      validate!
      Ai::Providers::OpenaiClient.new.chat(build_prompt)
    end

    private

    def validate!
      raise ArgumentError, "Content cannot be blank."              if @content.blank?
      raise ArgumentError, "Invalid mode: #{@mode.inspect}. " \
                           "Valid modes are: #{MODES.join(', ')}." unless MODES.include?(@mode)
    end

    # Each mode gets a tight, focused instruction. Rules common to all modes
    # are listed once at the bottom to keep individual instructions short.
    def build_prompt
      <<~PROMPT
        You are an AI writing assistant for a customer support agent.
        Rewrite the draft reply below according to the instruction for the selected mode.

        Mode: #{@mode.upcase}
        Instruction: #{mode_instruction}

        Rules that apply to every mode:
        - Preserve all factual information and any offered solutions.
        - Do NOT add information that was not in the original draft.
        - Keep markdown formatting (bold, lists, code blocks) if present.
        - Preserve any signature block (text after a `--` line) exactly as written.
        - Preserve any block-quoted customer text (lines starting with `>`) exactly as written.
        - Output ONLY the rewritten reply — no labels, no preamble, no explanation.
        - Keep the reply in the same language as the original draft.

        --- Draft reply ---
        #{@content}
        --- End of draft ---

        Rewritten reply:
      PROMPT
    end

    def mode_instruction
      case @mode
      when 'professional'
        'Make the reply formal, polished, and business-appropriate. Use complete sentences ' \
        'and proper grammar. Remove slang, contractions, and overly casual phrases.'
      when 'friendly'
        'Make the reply warm, approachable, and personable. Use conversational language, ' \
        'show empathy, and add positive phrases where natural (e.g. "Happy to help!"). ' \
        'Contractions are fine.'
      when 'shorter'
        'Make the reply as concise as possible without losing any key information. ' \
        'Remove filler words, redundant phrases, and unnecessary pleasantries. ' \
        'Every sentence must earn its place.'
      when 'clearer'
        'Make the reply easier to understand. Use simple words, short sentences, and ' \
        'plain language. Break up complex ideas. Avoid jargon and ambiguous phrasing.'
      end
    end
  end
end
