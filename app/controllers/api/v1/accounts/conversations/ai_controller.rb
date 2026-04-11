# frozen_string_literal: true

# app/controllers/api/v1/accounts/conversations/ai_controller.rb
#
# Thin controller for all AI features on a conversation.
# Business logic lives entirely in the service layer.
#
# Inherited from BaseController:
#   before_action :conversation  →  sets @conversation, scoped to Current.account,
#                                   authorized via Pundit (:show? policy).
#
# Routes (all under resource :ai in config/routes.rb):
#   POST .../ai/draft_reply
#   POST .../ai/summarize
#   POST .../ai/priority_score
#   POST .../ai/rewrite_reply     ← Phase 4
#
class Api::V1::Accounts::Conversations::AiController < Api::V1::Accounts::Conversations::BaseController
  # POST .../ai/draft_reply
  # Returns: { draft: "..." }
  def draft_reply
    draft = Ai::ReplyDrafterService.new(@conversation).draft

    if draft.present?
      render json: { draft: draft }
    else
      render json: { error: 'AI returned an empty response. Please try again.' },
             status: :unprocessable_entity
    end
  rescue ArgumentError => e
    Rails.logger.error("[AiController#draft_reply] Configuration error: #{e.message}")
    render json: { error: 'AI is not configured. Please contact your administrator.' },
           status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[AiController#draft_reply] Unexpected error: #{e.message}")
    render json: { error: 'Failed to generate AI draft. Please try again.' },
           status: :unprocessable_entity
  end

  # POST .../ai/summarize
  # Returns: { summary: "..." }
  def summarize
    summary = Ai::ConversationSummaryService.new(@conversation).summarize

    if summary.present?
      render json: { summary: summary }
    else
      render json: { error: 'AI returned an empty response. Please try again.' },
             status: :unprocessable_entity
    end
  rescue ArgumentError => e
    Rails.logger.error("[AiController#summarize] Configuration error: #{e.message}")
    render json: { error: 'AI is not configured. Please contact your administrator.' },
           status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[AiController#summarize] Unexpected error: #{e.message}")
    render json: { error: 'Failed to generate summary. Please try again.' },
           status: :unprocessable_entity
  end

  # POST .../ai/priority_score
  # Returns: { priority_score: 87, priority_label: "Urgent", reason: "..." }
  def priority_score
    result = Ai::ConversationPriorityService.new(@conversation).analyse

    render json: result
  rescue ArgumentError => e
    Rails.logger.error("[AiController#priority_score] Configuration error: #{e.message}")
    render json: { error: 'AI is not configured. Please contact your administrator.' },
           status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[AiController#priority_score] Unexpected error: #{e.message}")
    render json: { error: 'Failed to analyse priority. Please try again.' },
           status: :unprocessable_entity
  end

  # POST .../ai/rewrite_reply
  #
  # Params (JSON body):
  #   content [String] — the current draft text to rewrite (required)
  #   mode    [String] — one of: professional, friendly, shorter, clearer (required)
  #
  # Returns: { content: "..." }
  def rewrite_reply
    rewritten = Ai::ReplyRewriterService.new(
      content: rewrite_params[:content],
      mode:    rewrite_params[:mode]
    ).rewrite

    if rewritten.present?
      render json: { content: rewritten }
    else
      render json: { error: 'AI returned an empty response. Please try again.' },
             status: :unprocessable_entity
    end
  rescue ArgumentError => e
    # Covers blank content and invalid mode — both produce user-friendly messages
    Rails.logger.error("[AiController#rewrite_reply] Validation error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("[AiController#rewrite_reply] Unexpected error: #{e.message}")
    render json: { error: 'Failed to rewrite reply. Please try again.' },
           status: :unprocessable_entity
  end

  private

  def rewrite_params
    params.require(:ai).permit(:content, :mode)
  end
end
