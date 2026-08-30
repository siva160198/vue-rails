<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { Move, RotateCcw, RotateCw, ZoomIn, ZoomOut } from "@lucide/vue";
import AsyncButton from "../AsyncButton.vue";
import { t } from "../../services/i18n";

const props = defineProps({
  file: { type: File, required: true },
  loading: { type: Boolean, default: false },
});
const emit = defineEmits(["cancel", "confirm", "error"]);
const canvas = ref(null);
const zoom = ref(1);
const rotation = ref(0);
const offset = ref({ x: 0, y: 0 });
const ready = ref(false);
const image = new Image();
let objectUrl = "";
let dragging = false;
let pointer = { x: 0, y: 0 };
const SIZE = 640;

const rotatedSize = computed(() => rotation.value % 180 === 0
  ? { width: image.naturalWidth, height: image.naturalHeight }
  : { width: image.naturalHeight, height: image.naturalWidth });

function scale() {
  return Math.max(SIZE / rotatedSize.value.width, SIZE / rotatedSize.value.height) * zoom.value;
}

function clampOffset() {
  if (!ready.value) return;
  const currentScale = scale();
  const maxX = Math.max(0, (rotatedSize.value.width * currentScale - SIZE) / 2);
  const maxY = Math.max(0, (rotatedSize.value.height * currentScale - SIZE) / 2);
  const x = Math.max(-maxX, Math.min(maxX, offset.value.x));
  const y = Math.max(-maxY, Math.min(maxY, offset.value.y));
  if (x !== offset.value.x || y !== offset.value.y) offset.value = { x, y };
}

function draw() {
  if (!ready.value || !canvas.value) return;
  clampOffset();
  const context = canvas.value.getContext("2d");
  const currentScale = scale();
  context.clearRect(0, 0, SIZE, SIZE);
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, SIZE, SIZE);
  context.save();
  context.translate(SIZE / 2 + offset.value.x, SIZE / 2 + offset.value.y);
  context.rotate(rotation.value * Math.PI / 180);
  context.drawImage(image, -image.naturalWidth * currentScale / 2, -image.naturalHeight * currentScale / 2, image.naturalWidth * currentScale, image.naturalHeight * currentScale);
  context.restore();
}

function reset() {
  zoom.value = 1;
  rotation.value = 0;
  offset.value = { x: 0, y: 0 };
}

function rotate(amount) {
  rotation.value = (rotation.value + amount + 360) % 360;
  offset.value = { x: 0, y: 0 };
}

function startDrag(event) {
  if (!ready.value || props.loading) return;
  dragging = true;
  pointer = { x: event.clientX, y: event.clientY };
  event.currentTarget.setPointerCapture?.(event.pointerId);
}

function drag(event) {
  if (!dragging) return;
  const ratio = SIZE / canvas.value.getBoundingClientRect().width;
  offset.value = { x: offset.value.x + (event.clientX - pointer.x) * ratio, y: offset.value.y + (event.clientY - pointer.y) * ratio };
  pointer = { x: event.clientX, y: event.clientY };
}

function stopDrag() { dragging = false; }

function confirm() {
  if (!ready.value || props.loading) return;
  draw();
  canvas.value.toBlob((blob) => {
    if (!blob) return emit("error", t("profile.crop_failed"));
    emit("confirm", new File([blob], "avatar-cropped.jpg", { type: "image/jpeg", lastModified: Date.now() }));
  }, "image/jpeg", 0.92);
}

function loadImage() {
  ready.value = false;
  if (objectUrl) URL.revokeObjectURL(objectUrl);
  objectUrl = URL.createObjectURL(props.file);
  image.onload = async () => { ready.value = true; reset(); await nextTick(); draw(); };
  image.onerror = () => emit("error", t("profile.crop_preview_failed"));
  image.src = objectUrl;
}

watch([zoom, rotation, offset], draw, { deep: true });
watch(() => props.file, loadImage);
onMounted(loadImage);
onBeforeUnmount(() => { if (objectUrl) URL.revokeObjectURL(objectUrl); });
</script>

<template>
  <div class="space-y-5">
    <div class="rounded-xl border border-gray-200 bg-gray-50 p-3 dark:border-gray-800 dark:bg-gray-950">
      <div class="relative mx-auto aspect-square w-full max-w-md overflow-hidden rounded-xl bg-gray-200 touch-none dark:bg-gray-800">
        <canvas ref="canvas" :width="SIZE" :height="SIZE" class="h-full w-full cursor-move select-none" :aria-label="t('profile.crop_canvas')" @pointerdown="startDrag" @pointermove="drag" @pointerup="stopDrag" @pointercancel="stopDrag" />
        <div class="pointer-events-none absolute inset-0 rounded-full border-2 border-white/90 shadow-[0_0_0_999px_rgba(17,24,39,0.55)]" />
        <div v-if="!ready" role="status" class="absolute inset-0 flex items-center justify-center bg-gray-900/60 text-sm font-medium text-white">{{ t("common.loading_data") }}</div>
      </div>
      <p class="mt-3 flex items-center justify-center gap-2 text-center text-xs text-gray-500"><Move :size="15" />{{ t("profile.crop_drag_hint") }}</p>
    </div>

    <div>
      <div class="mb-2 flex items-center justify-between text-sm font-medium text-gray-700 dark:text-gray-300"><span>{{ t("profile.crop_zoom") }}</span><span>{{ Math.round(zoom * 100) }}%</span></div>
      <div class="flex items-center gap-3"><ZoomOut :size="18" class="text-gray-500" /><input v-model.number="zoom" type="range" min="1" max="3" step="0.01" :disabled="loading || !ready" class="h-2 w-full cursor-pointer accent-brand-500 disabled:cursor-not-allowed" :aria-label="t('profile.crop_zoom')" /><ZoomIn :size="18" class="text-gray-500" /></div>
    </div>

    <div class="flex flex-wrap gap-2">
      <AsyncButton type="button" :disabled="loading || !ready" class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="rotate(-90)"><RotateCcw :size="16" />{{ t("profile.crop_rotate_left") }}</AsyncButton>
      <AsyncButton type="button" :disabled="loading || !ready" class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="rotate(90)"><RotateCw :size="16" />{{ t("profile.crop_rotate_right") }}</AsyncButton>
      <AsyncButton type="button" :disabled="loading || !ready" class="rounded-lg border border-gray-200 px-3 py-2 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="reset">{{ t("profile.crop_reset") }}</AsyncButton>
    </div>

    <div class="flex justify-end gap-3 border-t border-gray-200 pt-4 dark:border-gray-800">
      <AsyncButton type="button" :disabled="loading" class="rounded-lg border border-gray-200 px-4 py-2.5 text-sm font-medium text-gray-700 dark:border-gray-700 dark:text-gray-200" @click="emit('cancel')">{{ t("common.cancel") }}</AsyncButton>
      <AsyncButton type="button" :loading="loading" :disabled="loading || !ready" class="rounded-lg bg-brand-500 px-4 py-2.5 text-sm font-semibold text-white" @click="confirm">{{ t("profile.crop_apply") }}</AsyncButton>
    </div>
  </div>
</template>
