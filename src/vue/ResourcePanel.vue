<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue';
import { get_resource, craft } from '../glue.js';
import {
  getResourceIcon,
  getResourceName,
  RESOURCE_META,
} from '../utils/mappings.js';
import { onEvent, offEvent, emitEvent, EventTypes } from '../utils/eventBus.js';
import { getAssetUrl } from '../utils/resourceLoader.js';
import './ResourcePanel.css';
const buildIconSrc = getAssetUrl('@assets/ui/panel5.png');
const panel5Src = `url('${buildIconSrc}')`;
const resources = ref({
  SpiritalSpark: 0,
  RecallGear: 0,
  ResonantCrystal: 0,
  RefinedCopper: 0,
  HeartCrystalDust: 0,
});
const recipeItems = [
  'HeartCrystalDust',
  'RecallGear',
  'ResonantCrystal',
  'RefinedCopper',
];
const isCrafting = ref(false);
const toast = ref({
  visible: false,
  success: true,
  text: '',
});
function showToast(text, success = true, durationMs = 1500) {
  toast.value = {
    visible: true,
    success,
    text,
  };
  window.clearTimeout(showToast._timer);
  showToast._timer = window.setTimeout(() => {
    toast.value.visible = false;
  }, durationMs);
}
async function handleCraft() {
  if (isCrafting.value) return;
  isCrafting.value = true;
  try {
    const result = craft();
    emitEvent(EventTypes.UPDATE_RESOURCES);
    if (result?.type === 'error') {
      showToast('合成失败', false);
    } else {
      showToast('合成成功', true);
    }
  } catch (e) {
    showToast('合成出错', false);
  } finally {
    isCrafting.value = false;
  }
}
async function updateResources() {
  try {
    const resourceData = get_resource();
    if (resourceData) {
      const changes = {};
      const newResources = {};
      Object.keys(resources.value).forEach(key => {
        const oldVal = resources.value[key];
        const newVal = resourceData[key] || 0;
        newResources[key] = newVal;
        const diff = newVal - oldVal;
        if (diff > 0) {
          changes[key] = diff;
        }
      });
      resources.value = newResources;
      emitEvent(EventTypes.RESOURCES_UPDATED, changes);
      return changes;
    }
  } catch (error) {
  }
  return {};
}
onMounted(() => {
  updateResources();
  onEvent(EventTypes.UPDATE_RESOURCES, updateResources);
});
onBeforeUnmount(() => {
  offEvent(EventTypes.UPDATE_RESOURCES, updateResources);
});
defineExpose({ updateResources });
</script>
<template>
  <div class="resource-panel">
    <div class="resource-header">
      <span class="header-text">资源</span>
    </div>
    <div class="resource-list">
      <div class="resource-layout">
        <div class="row row-top">
          <div
            class="resource-slot small"
            :title="getResourceName('RecallGear')"
          >
            <img
              v-if="getResourceIcon('RecallGear')"
              :src="getResourceIcon('RecallGear')"
              :alt="getResourceName('RecallGear')"
              class="resource-icon"
            />
            <div class="resource-count">{{ resources.RecallGear || 0 }}</div>
            <div class="resource-tooltip">
              {{ getResourceName('RecallGear') }}
            </div>
          </div>
          <div
            class="resource-slot small"
            :title="getResourceName('HeartCrystalDust')"
          >
            <img
              v-if="getResourceIcon('HeartCrystalDust')"
              :src="getResourceIcon('HeartCrystalDust')"
              :alt="getResourceName('HeartCrystalDust')"
              class="resource-icon"
            />
            <div class="resource-count">
              {{ resources.HeartCrystalDust || 0 }}
            </div>
            <div class="resource-tooltip">
              {{ getResourceName('HeartCrystalDust') }}
            </div>
          </div>
        </div>
        <div class="row row-middle">
          <div
            class="resource-slot large"
            :title="getResourceName('SpiritalSpark')"
          >
            <img
              v-if="getResourceIcon('SpiritalSpark')"
              :src="getResourceIcon('SpiritalSpark')"
              :alt="getResourceName('SpiritalSpark')"
              class="resource-icon"
            />
            <div class="resource-count">{{ resources.SpiritalSpark || 0 }}</div>
            <div class="resource-tooltip">
              {{ getResourceName('SpiritalSpark') }}
            </div>
          </div>
        </div>
        <div class="row row-bottom">
          <div
            class="resource-slot small"
            :title="getResourceName('ResonantCrystal')"
          >
            <img
              v-if="getResourceIcon('ResonantCrystal')"
              :src="getResourceIcon('ResonantCrystal')"
              :alt="getResourceName('ResonantCrystal')"
              class="resource-icon"
            />
            <div class="resource-count">
              {{ resources.ResonantCrystal || 0 }}
            </div>
            <div class="resource-tooltip">
              {{ getResourceName('ResonantCrystal') }}
            </div>
          </div>
          <div
            class="resource-slot small"
            :title="getResourceName('RefinedCopper')"
          >
            <img
              v-if="getResourceIcon('RefinedCopper')"
              :src="getResourceIcon('RefinedCopper')"
              :alt="getResourceName('RefinedCopper')"
              class="resource-icon"
            />
            <div class="resource-count">{{ resources.RefinedCopper || 0 }}</div>
            <div class="resource-tooltip">
              {{ getResourceName('RefinedCopper') }}
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="crafting-section">
      <div class="crafting-grid">
        <div class="craft-slot" v-for="(itemType, i) in recipeItems" :key="i">
          <img
            v-if="RESOURCE_META[itemType]?.icon"
            :src="RESOURCE_META[itemType].icon"
            class="craft-icon"
          />
          <div class="craft-count">
            {{ resources[itemType] || 0 }}
          </div>
        </div>
      </div>
      <div class="craft-arrow-group">
        <img
          class="craft-arrow-img"
          :src="getAssetUrl('@assets/ui/upgrade.png')"
          :alt="isCrafting ? '合成中' : '合成'"
          @click="handleCraft"
          :class="{ disabled: isCrafting }"
        />
        <div
          v-if="toast.visible"
          class="craft-toast"
          :class="{ success: toast.success, error: !toast.success }"
        >
          {{ toast.text }}
        </div>
      </div>
      <div class="craft-result">
        <div class="recipe-display">
          <img
            v-if="RESOURCE_META['SpiritalSpark']?.icon"
            :src="RESOURCE_META['SpiritalSpark'].icon"
            class="recipe-icon"
          />
          <div class="craft-count">
            {{ resources.SpiritalSpark || 0 }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<style scoped>
.resource-panel {
  border-image-source: v-bind(panel5Src);
}
</style>