<script setup>
import { ref, computed } from 'vue';
import { getAssetUrl } from '../../utils/resourceLoader.js';
import { getItemName, RESOURCE_META } from '../../utils/mappings.js';
import './SummonModal.css';
const panel6Src = `url('${getAssetUrl('@assets/ui/panel6.png')}')`;
const props = defineProps({
  visible: { type: Boolean, default: false },
  copperName: { type: String, default: '共鸣者' },
  enemyList: { type: Array, default: () => [] },
  position: { type: Array, default: null },
});
const emit = defineEmits(['close', 'summon']);
const selectedEnemy = ref(null);
const sortedEnemies = computed(() => {
  return [...props.enemyList].sort((a, b) => a.level - b.level);
});
function selectEnemy(enemy) {
  selectedEnemy.value = enemy;
}
function handleConfirm() {
  if (!selectedEnemy.value) {
    return;
  }
  emit('summon', selectedEnemy.value.name);
  handleClose();
}
function handleClose() {
  selectedEnemy.value = null;
  emit('close');
}
function getEnemyTypeLabel(type) {
  const typeMap = {
    goblin: '拾荒者',
    cruiser: '巡游者',
    scout: '斥候',
    boxer: '拳手',
    horn: '号手',
    assassin: '刺客',
    devourer: '吞噬者',
    mirror: '编织者',
    guard: '守卫',
    demon: '机妖',
    variant: '畸变体',
    shatra: 'BOSS',
    glutton: 'BOSS',
  };
  return typeMap[type] || type;
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
</script>
<template>
  <Teleport to="body">
    <div v-if="visible" class="modal-overlay" @click.self="handleClose">
      <div class="summon-modal" @click.stop>
        <div class="modal-header">
          <h2 class="modal-title">🔮 选择召唤目标</h2>
          <button class="close-btn" @click="handleClose" title="关闭">✕</button>
        </div>
        <div class="modal-info">
          <p class="info-text">
            <span class="copper-name">{{ copperName }}</span> 正在施展召唤术
          </p>
        </div>
        <div class="modal-body">
          <div class="enemy-list">
            <div
              v-for="enemy in sortedEnemies"
              :key="enemy.name"
              class="enemy-card"
              :class="{ selected: selectedEnemy?.name === enemy.name }"
              @click="selectEnemy(enemy)"
            >
              <div class="enemy-header">
                <div class="enemy-name-row">
                  <span class="enemy-name">{{ enemy.name }}</span>
                  <span class="enemy-level">Lv.{{ enemy.level }}</span>
                </div>
                <span class="enemy-type">{{
                  getEnemyTypeLabel(enemy.enemy_type)
                }}</span>
              </div>
              <div class="enemy-stats">
                <div class="stat">
                  <span class="stat-label">❤️</span>
                  <span class="stat-value">{{ enemy.health }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">⚔️</span>
                  <span class="stat-value">{{ enemy.attack }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">🛡️</span>
                  <span class="stat-value">{{ enemy.defense }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">📍</span>
                  <span class="stat-value">{{ enemy.attack_range }}</span>
                </div>
                <div class="stat">
                  <span class="stat-label">👟</span>
                  <span class="stat-value">{{ enemy.move_range }}</span>
                </div>
              </div>
              <div class="enemy-cost">
                <span class="cost-label">💰 召唤消耗：</span>
                <span class="cost-value">{{
                  formatCost(enemy.summon_cost)
                }}</span>
              </div>
              <div class="enemy-desc">{{ enemy.description }}</div>
              <div
                v-if="selectedEnemy?.name === enemy.name"
                class="selected-badge"
              >
                ✓ 已选择
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-cancel" @click="handleClose">取消</button>
          <button
            class="btn btn-confirm"
            :disabled="!selectedEnemy"
            @click="handleConfirm"
          >
            确认召唤
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
<style scoped>
.summon-modal {
  border-image-source: v-bind(panel6Src);
}
</style>