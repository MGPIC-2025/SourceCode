<script setup>
import { ref, computed } from 'vue';
import { getAssetUrl } from '../../utils/resourceLoader.js';
import { getItemName, RESOURCE_META } from '../../utils/mappings.js';
import './BuildModal.css';
const props = defineProps({
  visible: { type: Boolean, default: false },
  copperName: { type: String, default: '工匠' },
  structureList: { type: Array, default: () => [] },
  position: { type: Array, default: null },
});
const emit = defineEmits(['close', 'build']);
const selectedStructure = ref(null);
const sortedStructures = computed(() => {
  return [...props.structureList].sort((a, b) => {
    const getCost = item => {
      const costArray = item.cost?.cost || item.cost;
      if (!Array.isArray(costArray) || costArray.length === 0) return 0;
      return Array.isArray(costArray[0]) ? costArray[0][1] : costArray[0].count;
    };
    return getCost(a) - getCost(b);
  });
});
function selectStructure(structure) {
  selectedStructure.value = structure;
}
function handleConfirm() {
  if (!selectedStructure.value) {
    return;
  }
  emit('build', selectedStructure.value.name);
  handleClose();
}
function handleClose() {
  selectedStructure.value = null;
  emit('close');
}
function getStructureTypeLabel(name) {
  const typeMap = {
    心源矿钻: '资源采集',
    矿车: '资源运输',
    炮塔: '防御建筑',
    充能线圈: '能量建筑',
  };
  return typeMap[name] || '建筑';
}
function formatCost(costData) {
  if (!costData) return '无消耗';
  const costArray = costData.cost || costData;
  if (!Array.isArray(costArray) || costArray.length === 0) return '无消耗';
  return costArray
    .map(item => {
      if (Array.isArray(item)) {
        const resourceType = item[0];
        const count = item[1];
        const resourceName = RESOURCE_META[resourceType]?.name || resourceType;
        return `${resourceName} x${count}`;
      }
      return `${getItemName(item)} x${item.count}`;
    })
    .join(', ');
}
const panel11Src = `url('${getAssetUrl('@assets/ui/panel11.png')}')`;
const panel7Src = `url('${getAssetUrl('@assets/ui/panel7.png')}')`;
const panel8Src = `url('${getAssetUrl('@assets/ui/panel8.png')}')`;
const panel5Src = `url('${getAssetUrl('@assets/ui/panel5.png')}')`;
const panel12Src = `url('${getAssetUrl('@assets/ui/panel12.png')}')`;
</script>
<template>
  <Teleport to="body">
    <div v-if="visible" class="modal-overlay" @click.self="handleClose">
      <div class="build-modal" @click.stop>
        <div class="modal-header">
          <h2 class="modal-title">🔨 选择建造目标</h2>
          <button class="close-btn" @click="handleClose" title="关闭">
            <img :src="getAssetUrl('@assets/ui/close.png')" alt="关闭" />
          </button>
        </div>
        <div class="modal-info">
          <p class="info-text">
            <span class="copper-name">{{ copperName }}</span> 准备建造建筑
          </p>
          <p class="tip-text">
            💡 提示：心源矿钻只能建在矿物上，其他建筑建在空地上
          </p>
        </div>
        <div class="modal-body">
          <div class="structure-list">
            <div
              v-for="structure in sortedStructures"
              :key="structure.name"
              class="structure-card"
              :class="{ selected: selectedStructure?.name === structure.name }"
              @click="selectStructure(structure)"
            >
              <div class="structure-header">
                <div class="structure-name-row">
                  <span class="structure-name">{{ structure.name }}</span>
                </div>
                <span class="structure-type">{{
                  getStructureTypeLabel(structure.name)
                }}</span>
              </div>
              <div class="structure-stats">
                <div class="stat">
                  <span class="stat-label">❤️</span>
                  <span class="stat-value">{{ structure.health }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">⚔️</span>
                  <span class="stat-value">{{
                    structure.attribute?.attack || '无'
                  }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">📦</span>
                  <span class="stat-value">{{
                    structure.has_storage ? '有' : '无'
                  }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">📍</span>
                  <span class="stat-value">{{
                    structure.attack_range || '无'
                  }}</span>
                </div>
              </div>
              <div class="structure-cost">
                <span class="cost-label">💰 成本：</span>
                <span class="cost-value">{{ formatCost(structure.cost) }}</span>
              </div>
              <div class="structure-desc">{{ structure.description }}</div>
              <div
                v-if="selectedStructure?.name === structure.name"
                class="selected-badge"
              >
                ✓
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-cancel" @click="handleClose">取消</button>
          <button
            class="btn btn-confirm"
            :disabled="!selectedStructure"
            @click="handleConfirm"
          >
            确认建造
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
<style scoped>
.build-modal {
  border-image-source: v-bind(panel11Src);
}
.modal-info {
  border-image-source: v-bind(panel5Src);
}
.structure-card {
  border-image-source: v-bind(panel8Src);
}
.structure-card.selected {
  border-image-source: v-bind(panel7Src);
}
.selected-badge {
  border-image-source: v-bind(panel12Src);
}
</style>