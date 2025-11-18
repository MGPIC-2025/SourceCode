<script setup>
import { computed } from 'vue';
import { getAssetUrl } from '../../utils/resourceLoader.js';
import './InventoryModal.css';
const props = defineProps({
  visible: {
    type: Boolean,
    default: false,
  },
  copperName: {
    type: String,
    default: '未知铜偶',
  },
  equipment: {
    type: Array,
    default: () => [],
  },
});
const equipmentItems = computed(() => {
  return props.equipment || [];
});
const emit = defineEmits(['close']);
function close() {
  emit('close');
}
</script>
<template>
  <div v-if="visible" class="inventory-modal" @click.self="close">
    <div class="minecraft-inventory">
      <div class="inventory-layout">
        <div class="inventory-section">
          <div class="equipment-header-mc">
            <h4>
              <span class="copper-name">{{ copperName }}</span> 的装备
            </h4>
          </div>
          <div class="inventory-grid">
            <div
              v-for="(item, index) in 2"
              :key="index"
              class="inv-slot"
              :class="{
                'has-item':
                  index < equipmentItems.length &&
                  equipmentItems[index]?.equipped,
                'slot-locked': equipmentItems[index]?.locked,
              }"
            >
              <template v-if="index < equipmentItems.length">
                <div class="slot-icon">
                  <img
                    v-if="
                      equipmentItems[index]?.equipped &&
                      equipmentItems[index]?.icon &&
                      equipmentItems[index].icon !== '＋' &&
                      (equipmentItems[index].icon.startsWith('/') ||
                        equipmentItems[index].icon.startsWith('http') ||
                        equipmentItems[index].icon.includes('.'))
                    "
                    :src="equipmentItems[index].icon"
                    :alt="equipmentItems[index]?.name || '装备'"
                    class="equipment-icon"
                  />
                  <img
                    v-else-if="equipmentItems[index]?.locked"
                    :src="getAssetUrl('@assets/ui/lock.png')"
                    alt="未解锁"
                    class="equipment-icon"
                  />
                  <img
                    v-else-if="equipmentItems[index]?.icon === '＋'"
                    :src="getAssetUrl('@assets/ui/jia.png')"
                    alt="空槽"
                    class="equipment-icon"
                  />
                  <span v-else class="equipment-icon">{{
                    equipmentItems[index]?.icon || '＋'
                  }}</span>
                </div>
                <div class="slot-tooltip">
                  <div class="tooltip-name">
                    {{
                      equipmentItems[index]?.name ||
                      (equipmentItems[index]?.locked ? '未解锁' : '空槽')
                    }}
                  </div>
                </div>
              </template>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>