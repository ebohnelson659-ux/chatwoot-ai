<script setup>
// app/javascript/dashboard/components/widgets/conversation/AiPriorityScore.vue
//
// Accordion panel content for AI priority analysis.
// Rendered inside an <AccordionItem> in ContactPanel.vue.
//
// Mirrors AiConversationSummary.vue exactly in structure:
//   - <script setup> composition API
//   - ref() for local state
//   - watch() to reset on conversation change
//   - useAlert() for error surface
//   - useI18n() for all strings
//   - NextButton + Spinner from dashboard/components-next
//   - AiConversationApi for HTTP
//
// Result shape from the backend:
//   { priority_score: 0-100, priority_label: "Urgent"|"High"|"Medium"|"Low", reason: "..." }
//
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import AiConversationApi from 'dashboard/api/aiConversation';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();

const isLoading = ref(false);
const result    = ref(null); // null = not yet analysed

// Clear stale result when the agent switches conversations.
watch(
  () => props.conversationId,
  () => { result.value = null; }
);

// ── Colour mappings ────────────────────────────────────────────────────────
// Uses the n-* design tokens present throughout the rest of the sidebar.
// Each label gets a background, text, and border token for the pill badge,
// and a solid fill token for the progress bar.
const LABEL_BADGE_CLASSES = {
  Urgent: 'bg-n-ruby-3  text-n-ruby-11  border-n-ruby-6',
  High:   'bg-n-amber-3 text-n-amber-11 border-n-amber-6',
  Medium: 'bg-n-blue-3  text-n-blue-11  border-n-blue-6',
  Low:    'bg-n-slate-3 text-n-slate-11 border-n-slate-6',
};

const SCORE_BAR_CLASSES = {
  Urgent: 'bg-n-ruby-9',
  High:   'bg-n-amber-9',
  Medium: 'bg-n-blue-9',
  Low:    'bg-n-slate-7',
};

const badgeClasses    = label => LABEL_BADGE_CLASSES[label] ?? LABEL_BADGE_CLASSES.Low;
const scoreBarClass   = label => SCORE_BAR_CLASSES[label]   ?? SCORE_BAR_CLASSES.Low;
const scoreBarStyle   = score => ({ width: `${score}%` });

// ── API call ────────────────────────────────────────────────────────────────
const analyse = async () => {
  if (isLoading.value) return;

  isLoading.value = true;
  try {
    const { data } = await AiConversationApi.priorityScore(props.conversationId);
    result.value = data;
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t('AI_PRIORITY_SCORE.ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="px-4 pt-3 pb-4">

    <!-- ── Trigger button ─────────────────────────────────────────────────
         Label changes to "Re-analyse" once a result exists so the agent
         knows they can refresh it without needing to read the state.
    ──────────────────────────────────────────────────────────────────────── -->
    <NextButton
      ghost
      xs
      icon="i-lucide-bar-chart-2"
      :is-loading="isLoading"
      :label="
        result
          ? $t('AI_PRIORITY_SCORE.REANALYSE_BUTTON')
          : $t('AI_PRIORITY_SCORE.ANALYSE_BUTTON')
      "
      @click="analyse"
    />

    <!-- ── In-progress state ──────────────────────────────────────────────
         NextButton's built-in isLoading already disables the button;
         this gives a secondary visual signal while the request is in flight.
    ──────────────────────────────────────────────────────────────────────── -->
    <div
      v-if="isLoading"
      class="flex items-center gap-2 mt-3 text-sm text-n-slate-11"
    >
      <Spinner :size="14" />
      <span>{{ $t('AI_PRIORITY_SCORE.LOADING') }}</span>
    </div>

    <!-- ── Result card ────────────────────────────────────────────────────
         Surface tokens (bg-n-slate-2, border-n-weak) and text tokens
         (text-n-slate-12, text-n-slate-11) match the AiConversationSummary
         card so both panels look consistent in the sidebar.
    ──────────────────────────────────────────────────────────────────────── -->
    <div
      v-else-if="result"
      class="mt-3 rounded-lg bg-n-slate-2 border border-n-weak px-3 py-2.5 space-y-2.5"
    >
      <!-- Priority label pill + numeric score -->
      <div class="flex items-center justify-between gap-2">
        <span
          class="inline-flex items-center rounded-full border px-2 py-0.5
                 text-xs font-semibold tracking-wide leading-none"
          :class="badgeClasses(result.priority_label)"
        >
          {{ result.priority_label }}
        </span>
        <span class="text-sm font-semibold tabular-nums text-n-slate-12 shrink-0">
          {{ result.priority_score }}<span class="text-xs font-normal text-n-slate-11">/100</span>
        </span>
      </div>

      <!-- Score progress bar -->
      <div class="h-1.5 w-full rounded-full bg-n-slate-4 overflow-hidden">
        <div
          class="h-full rounded-full transition-[width] duration-500 ease-out"
          :class="scoreBarClass(result.priority_label)"
          :style="scoreBarStyle(result.priority_score)"
        />
      </div>

      <!-- Reason sentence -->
      <p class="text-xs text-n-slate-11 leading-relaxed">
        {{ result.reason }}
      </p>
    </div>

    <!-- ── Pre-analysis hint ──────────────────────────────────────────────
         Shown before the agent has clicked Analyse for the first time.
         Same muted style used by AiConversationSummary's empty state.
    ──────────────────────────────────────────────────────────────────────── -->
    <p
      v-else
      class="mt-2 text-xs text-n-slate-11"
    >
      {{ $t('AI_PRIORITY_SCORE.EMPTY_STATE') }}
    </p>

  </div>
</template>
