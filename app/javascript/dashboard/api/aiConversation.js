/* global axios */

// app/javascript/dashboard/api/aiConversation.js
//
// API client for all AI features on a conversation.
//
// Uses the same ApiClient base class and `accountScoped: true` pattern as every
// other Chatwoot API file (LinearAPI, ConversationApi, etc.).
//
// Usage:
//   import AiConversationApi from 'dashboard/api/aiConversation';
//
//   const { data } = await AiConversationApi.summarize(conversationId);
//   // => { summary: "..." }
//
//   const { data } = await AiConversationApi.draftReply(conversationId);
//   // => { draft: "..." }
//
//   const { data } = await AiConversationApi.priorityScore(conversationId);
//   // => { priority_score: 87, priority_label: "Urgent", reason: "..." }
//
//   const { data } = await AiConversationApi.rewriteReply(conversationId, content, mode);
//   // => { content: "Thank you for reaching out! I'd be happy to help..." }
//
import ApiClient from './ApiClient';

class AiConversationApi extends ApiClient {
  constructor() {
    // Builds base URL: /api/v1/accounts/:accountId/conversations
    super('conversations', { accountScoped: true });
  }

  // POST /api/v1/accounts/:accountId/conversations/:conversationId/ai/summarize
  summarize(conversationId) {
    return axios.post(`${this.url}/${conversationId}/ai/summarize`);
  }

  // POST /api/v1/accounts/:accountId/conversations/:conversationId/ai/draft_reply
  draftReply(conversationId) {
    return axios.post(`${this.url}/${conversationId}/ai/draft_reply`);
  }

  // POST /api/v1/accounts/:accountId/conversations/:conversationId/ai/priority_score
  priorityScore(conversationId) {
    return axios.post(`${this.url}/${conversationId}/ai/priority_score`);
  }

  // POST /api/v1/accounts/:accountId/conversations/:conversationId/ai/rewrite_reply
  //
  // @param {number|string} conversationId
  // @param {string}        content  — current draft text in the reply box
  // @param {string}        mode     — one of: professional, friendly, shorter, clearer
  rewriteReply(conversationId, content, mode) {
    return axios.post(`${this.url}/${conversationId}/ai/rewrite_reply`, {
      ai: { content, mode },
    });
  }
}

export default new AiConversationApi();
