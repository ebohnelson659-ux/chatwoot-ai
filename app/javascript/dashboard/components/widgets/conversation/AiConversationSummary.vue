<script setup>
// app/javascript/dashboard/components/widgets/conversation/AiConversationSummary.vue
//
// Self-contained accordion panel content for AI conversation summaries.
// Rendered inside an <AccordionItem> in ContactPanel.vue.
//
// Responsibilities:
//   - Render a "Generate Summary" / "Regenerate" button
//   - Call the backend summarize endpoint via AiConversationApi
//   - Show a loading state while the request is in flight
//   - Display the returned summary in a styled card
//   - Reset when the agent switches to a different conversation
//
// Pattern mirrors LinearIssuesList.vue:
//   - <script setup> composition API
//   - ref() for local state
//   - watch() to reset on prop change
//   - useAlert() for error surface
//   - useI18n() for all strings
//   - NextButton + Spinner from dashboard/components-next
//
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AiConversationApi from 'dashboard/api/aiConversation';

const props = defineProps({
  // The conversation's display_id — matches what the backend BaseController
  // uses to look up the conversation (find_by!(display_id: ...)).
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const isLoading = ref(false);
const summary = ref('');

// When the agent switches conversations, clear the previous summary so stale
// content from another thread never appears.
watch(
  () => props.conversationId,
  () => {
    summary.value = '';
  }
);

const generateSummary = async () => {
  // Guard against double-clicks / concurrent requests
  if (isLoading.value) return;

  isLoading.value = true;
  try {
    const { data } = await AiConversationApi.summarize(props.conversationId);
    summary.value = data.summary || '';
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('AI_CONVERSATION_SUMMARY.ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="px-4 pt-3 pb-4">

    <!--
      Generate / Regenerate trigger.
      Label changes after the first successful generation so the agent
      knows they can refresh it. isLoading disables the button and shows
      NextButton's built-in spinner.
    -->
    <NextButton
      ghost
      xs
      icon="i-lucide-sparkles"
      :is-loading="isLoading"
      :label="
        summary
          ? $t('AI_CONVERSATION_SUMMARY.REGENERATE_BUTTON')
          : $t('AI_CONVERSATION_SUMMARY.GENERATE_BUTTON')
      "
      @click="generateSummary"
    />

    <!--
      In-progress state — shown while the API call is running.
      NextButton already disables itself via isLoading, so this is purely
      a visual affordance so the agent knows something is happening.
    -->
    <div
      v-if="isLoading"
      class="flex items-center gap-2 mt-3 text-sm text-n-slate-11"
    >
      <Spinner :size="14" />
      <span>{{ $t('AI_CONVERSATION_SUMMARY.LOADING') }}</span>
    </div>

    <!--
      Summary card — shown after a successful generation.
      Uses the same surface / border / text tokens as the rest of the sidebar
      (bg-n-slate-2, border-n-weak, text-n-slate-12) so it fits without
      custom colour values.
    -->
    <div
      v-else-if="summary"
      class="mt-3 text-sm text-n-slate-12 leading-relaxed
             bg-n-slate-2 rounded-lg px-3 py-2.5
             border border-n-weak"
    >
      {{ summary }}
    </div>

    <!--
      Pre-generation hint — shown before the agent has clicked Generate.
      Muted slate text, same size as other sidebar helper copy.
    -->
    <p
      v-else
      class="mt-2 text-xs text-n-slate-11"
    >
      {{ $t('AI_CONVERSATION_SUMMARY.EMPTY_STATE') }}
    </p>

  </div>
</template>
