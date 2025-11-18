<script setup>
import { ref, computed, watch } from 'vue';
import { eventloop } from '../glue.js';
import { getItemName } from '../utils/mappings.js';
import { getAssetUrl } from '../utils/resourceLoader.js';
import DiamondPanel from './ActionPanelParts/DiamondPanel.vue';
import InventoryModal from './ActionPanelParts/InventoryModal.vue';
import HealthBar from './ActionPanelParts/HealthBar.vue';
import TriPanel from './ActionPanelParts/TriPanel.vue';
import BuildModal from './ActionPanelParts/BuildModal.vue';
import './ActionPanel.css';
const props = defineProps({
  copper: {
    type: Object,
    default: null,
  },
  resources: {
    type: Array,
    default: () => [],
  },
  hasAttackTargets: {
    type: Boolean,
    default: true,
  },
  onSelectCopper: {
    type: Function,
    default: null,
  },
});
const emit = defineEmits(['close', 'action', 'selectCopper']);
const swordImgSrc = computed(() => `url('${getAssetUrl('ui/sword.png')}')`);
const redPanelBg = computed(() => `url('${getAssetUrl('ui/red.png')}')`);
const bootImgSrc = computed(() => `url('${getAssetUrl('ui/boot.png')}')`);
const greenPanelBg = computed(() => `url('${getAssetUrl('ui/green.png')}')`);
const buildImgSrc = computed(
  () => `url('${getAssetUrl('@assets/ui/build.png')}')`
);
const summonImgSrc = computed(
  () => `url('${getAssetUrl('@assets/ui/summon.png')}')`
);
const closeIconSrc = getAssetUrl('@assets/ui/close.png');
const panelMode = ref('full');
const actionMode = ref(null);
const showInventory = ref(false);
const showBuildModal = ref(false);
const structureList = ref([]);
const copperInfo = computed(() => {
  if (!props.copper) return null;
  const derivedName =
    props.copper.copper?.copper_info?.name ||
    props.copper.enemy?.enemy_base?.name ||
    props.copper.enemy_base?.name ||
    props.copper.name ||
    `单位 #${props.copper.id}`;
  return {
    id: props.copper.id,
    name: derivedName,
    level:
      props.copper.copper?.level ??
      props.copper.enemy?.level ??
      props.copper.enemy_base?.level ??
      1,
    hp: props.copper.now_health,
    maxHp:
      props.copper.copper?.attribute?.health ??
      props.copper.enemy?.enemy_base?.health ??
      props.copper.enemy_base?.health ??
      100,
    attack:
      props.copper.copper?.attribute?.attack ??
      props.copper.enemy?.enemy_base?.attack ??
      props.copper.enemy_base?.attack ??
      0,
    defense:
      props.copper.copper?.attribute?.defense ??
      props.copper.enemy?.enemy_base?.defense ??
      props.copper.enemy_base?.defense ??
      0,
    speed:
      props.copper.copper?.attribute?.speed ??
      props.copper.enemy?.enemy_base?.speed ??
      props.copper.enemy_base?.speed ??
      0,
    canMove: props.copper.can_move,
    canAttack: props.copper.can_attack,
    canSummon: props.copper.can_summon,
    position:
      Array.isArray(props.copper.position) && props.copper.position.length >= 2
        ? props.copper.position
        : Array.isArray(props.copper.enemy?.position) &&
            props.copper.enemy.position.length >= 2
          ? props.copper.enemy.position
          : Array.isArray(props.copper.enemy_base?.position) &&
              props.copper.enemy_base.position.length >= 2
            ? props.copper.enemy_base.position
            : [0, 0],
    inventoryCapacity: props.copper.inventory?.capacity || 0,
    copperType:
      props.copper.copper?.copper_type ||
      props.copper.enemy?.enemy_base?.enemy_type ||
      props.copper.enemy_base?.enemy_type ||
      '',
    isOwnedEnemy: props.copper.isOwnedEnemy === true,
    isEnemy: props.copper.isEnemy === true,
  };
});
const equipmentData = computed(() => {
  if (!props.copper) return [];
  const equipmentSlot = props.copper.copper?.equipment_slot || {};
  const slot1 = equipmentSlot?.slot1 || null;
  const slot2 = equipmentSlot?.slot2 || null;
  return [
    slot1
      ? {
          name: slot1.equipment_base?.name || '装备',
          icon: getAssetUrl(slot1.equipment_base?.resource_url || ''),
          equipped: true,
          locked: false,
        }
      : { name: '空槽', icon: '＋', equipped: false, locked: false },
    equipmentSlot?.is_slot2_locked
      ? { name: '未解锁', icon: '🔒', equipped: false, locked: true }
      : slot2
        ? {
            name: slot2.equipment_base?.name || '装备',
            icon: getAssetUrl(slot2.equipment_base?.resource_url || ''),
            equipped: true,
            locked: false,
          }
        : { name: '空槽', icon: '＋', equipped: false, locked: false },
  ];
});
watch(
  () => props.copper?.id,
  (newId, oldId) => {
    if (newId === oldId) return;
    panelMode.value = 'full';
    actionMode.value = null;
    showInventory.value = false;
    showBuildModal.value = false;
  }
);
async function handleMove() {
  if (!copperInfo.value.canMove) return;
  const isOwnedEnemy = props.copper.isOwnedEnemy === true;
  const eventType = isOwnedEnemy ? 'on_enemy_move_start' : 'on_move_start';
  const message = JSON.stringify({
    type: eventType,
    content: { id: String(copperInfo.value.id) },
  });
  eventloop(message);
  panelMode.value = 'minimized';
  actionMode.value = 'moving';
  emit('action', { type: 'moveStart', copperId: copperInfo.value.id });
}
async function handleAttack() {
  if (!copperInfo.value.canAttack) {
    return;
  }
  const isOwnedEnemy = props.copper.isOwnedEnemy === true;
  const eventType = isOwnedEnemy ? 'on_enemy_attack_start' : 'on_attack_start';
  const message = JSON.stringify({
    type: eventType,
    content: { id: String(copperInfo.value.id) },
  });
  eventloop(message);
  panelMode.value = 'minimized';
  actionMode.value = 'attacking';
  emit('action', { type: 'attackStart', copperId: copperInfo.value.id });
}
async function handleSummon() {
  if (!copperInfo.value.canSummon) {
    return;
  }
  const message = JSON.stringify({
    type: 'on_summon_start',
    content: { id: String(copperInfo.value.id) },
  });
  eventloop(message);
  panelMode.value = 'minimized';
  actionMode.value = 'summoning';
  emit('action', { type: 'summonStart', copperId: copperInfo.value.id });
}
async function handleBuild() {
  if (!copperInfo.value.canSummon) {
    return;
  }
  emit('action', {
    type: 'buildRequest',
    copperId: copperInfo.value.id,
  });
}
function showBuildMenu(structures) {
  structureList.value = structures || [];
  showBuildModal.value = true;
}
async function handleBuildConfirm(structureName) {
  showBuildModal.value = false;
  const startMessage = JSON.stringify({
    type: 'on_structure_build_start',
    content: { id: String(copperInfo.value.id), name: structureName },
  });
  eventloop(startMessage);
  panelMode.value = 'minimized';
  actionMode.value = 'building';
  emit('action', {
    type: 'buildStart',
    copperId: copperInfo.value.id,
    structureName: structureName,
  });
}
function handleInventory() {
  showInventory.value = true;
}
async function handlePickup(index) {
  const message = JSON.stringify({
    type: 'on_copper_pick_up',
    content: { id: String(copperInfo.value.id), index: String(index) },
  });
  eventloop(message);
  await refreshCopperState();
}
async function handleCraft() {
  const message = JSON.stringify({
    type: 'on_copper_craft',
    content: { id: String(copperInfo.value.id) },
  });
  eventloop(message);
  await refreshCopperState();
}
async function handleInventoryCraft() {
  await handleCraft();
}
async function refreshCopperState() {
  const isOwnedEnemy = props.copper.isOwnedEnemy === true;
  const eventType = isOwnedEnemy ? 'on_click_enemy' : 'on_click_copper';
  const message = JSON.stringify({
    type: eventType,
    content: { id: String(copperInfo.value.id) },
  });
  eventloop(message);
}
function handleWait() {
  emit('action', { type: 'wait', copperId: copperInfo.value.id });
}
function close() {
  panelMode.value = 'full';
  actionMode.value = null;
  showInventory.value = false;
  emit('close');
}
function handleCloseInventory() {
  showInventory.value = false;
}
function cancelAction() {
  panelMode.value = 'full';
  actionMode.value = null;
  emit('action', { type: 'cancel', copperId: copperInfo.value.id });
}
function handleMinimizedClose() {
  cancelAction();
  close();
}
async function handleSelectCopper(copperId) {
  if (props.onSelectCopper) {
    await props.onSelectCopper(copperId);
  } else {
    emit('selectCopper', copperId);
  }
}
defineExpose({ cancelAction, handleSelectCopper, showBuildMenu });
</script>
<template>
  <div v-if="copper" class="copper-panel-parent">
    <DiamondPanel
      :copper-info="copperInfo"
      :inventory-items="[]"
      :inventory-capacity="5"
      @inventory-click="handleInventory"
    />
    <HealthBar :hp="copperInfo?.hp || 0" :max-hp="copperInfo?.maxHp || 100" />
    <div
      v-if="
        panelMode === 'minimized' ||
        (resources && resources.length > 0 && panelMode === 'full')
      "
      class="copper-panel"
      :class="{
        'copper-panel--minimized': panelMode === 'minimized',
        'copper-panel--min-attack':
          panelMode === 'minimized' && actionMode === 'attacking',
        'copper-panel--min-move':
          panelMode === 'minimized' && actionMode === 'moving',
        'copper-panel--min-summon':
          panelMode === 'minimized' && actionMode === 'summoning',
        'copper-panel--min-build':
          panelMode === 'minimized' && actionMode === 'building',
      }"
      @click.stop
    >
      <div v-if="panelMode === 'minimized'" class="minimized-content">
        <button
          class="minimized-close"
          type="button"
          @click="handleMinimizedClose"
          title="关闭"
        >
          <img :src="closeIconSrc" alt="关闭" />
        </button>
        <div class="minimized-info">
          <span class="minimized-name">{{ copperInfo.name }}</span>
          <span class="minimized-action">
            {{
              actionMode === 'moving'
                ? '选择移动位置...'
                : actionMode === 'attacking'
                  ? '选择攻击目标...'
                  : actionMode === 'summoning'
                    ? '选择召唤位置...'
                    : actionMode === 'building'
                      ? '选择建造位置...'
                      : ''
            }}
          </span>
        </div>
      </div>
      <template v-else>
        <button class="close-btn" @click="close" title="关闭">
          <img :src="closeIconSrc" alt="关闭" />
        </button>
        <div class="panel-content">
          <div v-if="resources && resources.length > 0" class="resources">
            <div class="resources-header">📦 地面物品</div>
            <div class="resources-list">
              <div
                v-for="(resource, index) in resources"
                :key="index"
                class="resource-item"
                @click="handlePickup(index)"
                title="点击拾取"
              >
                <span class="resource-name">{{ getItemName(resource) }}</span>
                <span class="resource-count">x{{ resource.count || 1 }}</span>
                <span class="resource-pickup">⬆️</span>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>
    <!-- 操作三角图标（野生敌人不显示操作按钮） -->
    <TriPanel
      v-if="!props.copper.isEnemy"
      :copper-type="copperInfo?.copperType"
      :can-move="copperInfo?.canMove !== false"
      :can-attack="copperInfo?.canAttack !== false"
      :can-summon="copperInfo?.canSummon !== false"
      @move="handleMove"
      @wait="handleWait"
      @attack="handleAttack"
      @summon="handleSummon"
      @build="handleBuild"
    />
    <!-- 野生敌人提示 -->
    <div v-if="props.copper.isEnemy" class="enemy-info-tip">
      <span>🔍 查看模式（敌人单位）</span>
    </div>
  </div>
  <!-- 资源弹窗 -->
  <InventoryModal
    :visible="showInventory"
    :copper-name="copperInfo?.name || '未知铜偶'"
    :equipment="equipmentData"
    @close="handleCloseInventory"
    @craft="handleInventoryCraft"
  />
  <!-- 建造弹窗 -->
  <BuildModal
    :visible="showBuildModal"
    :copper-name="copperInfo?.name || '未知铜偶'"
    :structure-list="structureList"
    @close="showBuildModal = false"
    @build="handleBuildConfirm"
  />
</template>
<style scoped>
/* 边框：攻击 = 红色；移动 = 绿色（仅在最小化时生效） */
.copper-panel--minimized.copper-panel--min-attack {
  border: none;
  /* Two-layer background: top = sword badge, bottom = red panel */
  background-image: v-bind(swordImgSrc), v-bind(redPanelBg);
  background-repeat: no-repeat, no-repeat;
  background-position:
    8px 8px,
    center;
  /* keep red panel slightly expanded to compensate asset margins */
  background-size:
    32px 32px,
    130% 122%;
  background-origin: padding-box, border-box;
  background-clip: padding-box, border-box;
  image-rendering: pixelated;
}
.copper-panel--minimized.copper-panel--min-move {
  border: none;
  /* Two-layer background: top = boot badge, bottom = green panel */
  background-image: v-bind(bootImgSrc), v-bind(greenPanelBg);
  background-repeat: no-repeat, no-repeat;
  background-position:
    8px 8px,
    center;
  /* keep green panel slightly expanded to compensate asset margins */
  background-size:
    32px 32px,
    130% 122%;
  background-origin: padding-box, border-box;
  background-clip: padding-box, border-box;
  image-rendering: pixelated;
}
.copper-panel--minimized.copper-panel--min-summon {
  border: none;
  /* Two-layer background: top = summon badge, bottom = green panel */
  background-image: v-bind(summonImgSrc), v-bind(greenPanelBg);
  background-repeat: no-repeat, no-repeat;
  background-position:
    8px 8px,
    center;
  /* keep green panel slightly expanded to compensate asset margins */
  background-size:
    32px 32px,
    130% 122%;
  background-origin: padding-box, border-box;
  background-clip: padding-box, border-box;
  image-rendering: pixelated;
}
.copper-panel--minimized.copper-panel--min-build {
  border: none;
  /* Two-layer background: top = build badge, bottom = green panel */
  background-image: v-bind(buildImgSrc), v-bind(greenPanelBg);
  background-repeat: no-repeat, no-repeat;
  background-position:
    8px 8px,
    center;
  /* keep green panel slightly expanded to compensate asset margins */
  background-size:
    32px 32px,
    130% 122%;
  background-origin: padding-box, border-box;
  background-clip: padding-box, border-box;
  image-rendering: pixelated;
}
</style>