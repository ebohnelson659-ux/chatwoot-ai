# frozen_string_literal: true

# app/services/ai/conversation_priority_service.rb
#
# Analyses a conversation and returns a structured priority assessment.
#
# Responsibilities:
#   1. Format the conversation via the shared LLM formatter
#   2. Build a JSON-requesting prompt
#   3. Delegate the LLM call to the existing provider wrapper
#   4. Parse and normalise the model's response into a guaranteed shape
#
# Design decisions vs the other AI services:
#   - Requests JSON output from the model (no markdown fences) for reliable parsing
#   - include_private_messages: true  — internal notes can signal severity
#   - include_contact_details: true   — VIP / repeat-contact context matters for priority
#   - Larger MAX_TOKENS budget (256) because the model must emit a JSON object
#   - Normalisation layer means the controller always gets a clean Hash or an error
#
# Returns a Hash:
#   {
#     priority_score: Integer (0–100),
#     priority_label: String  ("Urgent" | "High" | "Medium" | "Low"),
#     reason:         String  (one short sentence)
#   }
#
# Usage:
#   result = Ai::ConversationPriorityService.new(conversation).analyse
#   # => { priority_score: 87, priority_label: "Urgent", reason: "..." }
#
module Ai
  class ConversationPriorityService
    # ~10 000 chars gives the model enough thread context to make a meaningful
    # priority judgement without approaching token limits.
    CONVERSATION_CHAR_LIMIT = 10_000

    # Maps score ranges → canonical label.  Order matters — first match wins.
    SCORE_LABEL_THRESHOLDS = [
      [75, 'Urgent'],
      [50, 'High'],
      [25, 'Medium'],
      [0,  'Low']
    ].freeze

    VALID_LABELS = %w[Urgent High Medium Low].freeze

    def initialize(conversation)
      @conversation = conversation
    end

    # @return [Hash] { priority_score:, priority_label:, reason: }
    # @raise [StandardError] if the provider call fails (caller handles rescue)
    def analyse
      context  = format_conversation
      raw_text = Ai::Providers::OpenaiClient.new.chat(build_prompt(context))
      parse_response(raw_text)
    end

    private

    def format_conversation
      LlmFormatter::ConversationLlmFormatter
        .new(@conversation)
        .format(
          token_limit:              CONVERSATION_CHAR_LIMIT,
          include_private_messages: true,
          include_contact_details:  true
        )
    end

    # Instructs the model to return a strict JSON object so we can parse it
    # deterministically.  Fenced markdown blocks are explicitly forbidden to
    # prevent the most common LLM formatting mistake.
    def build_prompt(context)
      <<~PROMPT
        You are an expert customer support triage specialist.
        Analyse the conversation below and assess its support priority.

        Return ONLY a valid JSON object — no markdown, no code fences, no extra text.
        The object must have exactly these three keys:

          "priority_score"  — integer from 0 (lowest) to 100 (highest urgency)
          "priority_label"  — one of: "Urgent", "High", "Medium", or "Low"
          "reason"          — one concise sentence (max 20 words) explaining the score

        Scoring guidance:
          75–100  Urgent  — business-critical issue, outage, legal/financial risk, very frustrated customer, VIP
          50–74   High    — significant impact, customer blocked, unresolved for >24h, escalation risk
          25–49   Medium  — moderate inconvenience, workaround exists, timely follow-up needed
          0–24    Low     — general enquiry, minor issue, customer is patient, no urgency signals

        --- Conversation ---
        #{context}
        --- End of conversation ---
      PROMPT
    end

    # Parses the raw model output into a normalised Hash.
    # If parsing fails for any reason we surface a controlled error rather
    # than letting a JSON::ParserError bubble up uncaught through the controller.
    def parse_response(raw_text)
      raise ArgumentError, 'AI returned an empty response' if raw_text.blank?

      json = extract_json(raw_text)
      data = JSON.parse(json)

      score = normalise_score(data['priority_score'])
      label = normalise_label(data['priority_label'], score)
      reason = data['reason'].to_s.strip.presence || 'No reason provided.'

      { priority_score: score, priority_label: label, reason: reason }
    rescue JSON::ParserError => e
      Rails.logger.error("[Ai::ConversationPriorityService] JSON parse failed: #{e.message} | raw=#{raw_text.inspect}")
      raise StandardError, 'AI returned an unparseable response. Please try again.'
    end

    # Strip accidental markdown fences the model may have added despite instructions.
    # Matches both ```json ... ``` and bare ``` ... ``` blocks.
    def extract_json(text)
      if (match = text.match(/```(?:json)?\s*(\{.*?\})\s*```/m))
        match[1]
      else
        # Fall back to first {...} substring in case model prefixed extra words
        text[/\{.*\}/m] || text
      end
    end

    # Clamp to 0–100 and ensure it is an integer.
    def normalise_score(raw)
      raw.to_i.clamp(0, 100)
    end

    # Accept the label from the model if it is in our canonical set; otherwise
    # derive it from the score so we always return a valid label.
    def normalise_label(raw_label, score)
      candidate = raw_label.to_s.strip.capitalize
      return candidate if VALID_LABELS.include?(candidate)

      # Derive from score as fallback
      _, label = SCORE_LABEL_THRESHOLDS.find { |threshold, _| score >= threshold }
      label
    end
  end
end
