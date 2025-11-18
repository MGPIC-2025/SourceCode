<script setup>
import { ref, onMounted, onBeforeUnmount, nextTick } from 'vue';
import Hall from './vue/Hall.vue';
import Warehouse from './vue/Warehouse.vue';
import TopLeftPanel from './vue/TopLeftPanel.vue';
import StartMenu from './vue/StartMenu.vue';
import StartGame from './vue/StartGame.vue';
import GameScene from './vue/GameScene.vue';
import { getAssetUrl } from './utils/resourceLoader.js';
import { getSettings, updateSetting } from './utils/gameSettings.js';
import './App.css';
import { info_subscribe, export_save, import_save } from './glue.js';
const isPaused = ref(false);
const overlay = ref(null);
const showSettingsOverlay = ref(false);
const warehouseRef = ref(null);
const overlayHistory = ref([]);
const currentPuppetIndex = ref(0);
const showStartMenu = ref(true);
const showGameScene = ref(false);
const controlMode = ref('touchpad');
const destroyStartMenu = ref(false);
let startMenuDestroyTimer = null;
function togglePause() {
  isPaused.value = !isPaused.value;
  (isPaused.value ? window.__START_MENU_PAUSE__ : window.__START_MENU_RESUME__)?.();
}
function openOverlay(type) {
  if (overlay.value !== type) {
    overlayHistory.value.push(overlay.value);
    overlay.value = type;
  }
  window.__START_MENU_PAUSE__?.();
  isPaused.value = true;
}
function openTutorial() {
  window.open('https://www.bilibili.com/video/BV19UCwBzE1Z/', '_blank');
}
function onStartMenuStarted() {
  showStartMenu.value = false;
  if (startMenuDestroyTimer) {
    clearTimeout(startMenuDestroyTimer);
  }
  startMenuDestroyTimer = setTimeout(
    () => {
      if (!showStartMenu.value) {
        destroyStartMenu.value = true;
      }
    },
    5 * 60 * 1000
  );
}
function closeOverlay() {
  overlay.value = null;
  overlayHistory.value = [];
  window.__START_MENU_RESUME__?.();
  isPaused.value = false;
}
function handleGameStart(params) {
  closeOverlay();
  showGameScene.value = true;
}
function closeGameScene() {
  showGameScene.value = false;
}
function openSettings() {
  const settings = getSettings();
  controlMode.value = settings.controlMode;
  showSettingsOverlay.value = true;
  isPaused.value = true;
}
function closeSettings() {
  showSettingsOverlay.value = false;
  if (!overlay.value) {
    window.__START_MENU_RESUME__?.();
    isPaused.value = false;
  }
}
function setControlMode(mode) {
  controlMode.value = mode;
  updateSetting('controlMode', mode);
  window.updateControlMode?.(mode);
}
function goBack() {
  if (showSettingsOverlay.value) {
    closeSettings();
    return;
  }
  if (overlay.value) {
    if (overlay.value === 'warehouse' && warehouseRef.value?.handleBack?.()) return;
    overlay.value = overlayHistory.value.pop() ?? null;
    if (!overlay.value) isPaused.value = false;
    return;
  }
  if (!showStartMenu.value) {
    if (startMenuDestroyTimer) {
      clearTimeout(startMenuDestroyTimer);
      startMenuDestroyTimer = null;
    }
    destroyStartMenu.value = false;
    showStartMenu.value = true;
    setTimeout(() => {
      const resume = () => window.__START_MENU_RESUME__?.();
      window.__INIT_THREE_SCENE__?.().then(resume).catch(resume) || resume();
    }, 100);
    isPaused.value = false;
  }
}
const musicOn = ref(true);
const fileInput = ref(null);
function onToggleMusic() {
  musicOn.value = !musicOn.value;
}
async function onDownloadSave() {
  try {
    const saveData = export_save();
    if (saveData.type === 'error') {
      alert('导出存档失败: ' + saveData.content);
      return;
    }
    const blob = new Blob([JSON.stringify(saveData, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `mgpic-save-${new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5)}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  } catch {
    alert('下载存档失败，请重试');
  }
}
function onUploadSave() {
  fileInput.value?.click();
}
async function onFileChange(ev) {
  const file = ev.target?.files?.[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      import_save(String(reader.result || '{}'));
      alert('存档导入成功！');
    } catch (error) {
      alert('导入存档失败: ' + error.message);
    }
    ev.target.value = '';
  };
  reader.onerror = () => {
    alert('读取文件失败，请重试');
    ev.target.value = '';
  };
  reader.readAsText(file);
}
onMounted(() => {
  info_subscribe(() => {});
});
onBeforeUnmount(() => {
  if (startMenuDestroyTimer) {
    clearTimeout(startMenuDestroyTimer);
    startMenuDestroyTimer = null;
  }
});
</script>
<template>
  <div class="stage">
    <GameScene
      v-if="showGameScene"
      :isGameMode="true"
      :music-on="musicOn"
      @back="closeGameScene"
    />
    <template v-if="!showGameScene">
      <StartMenu
        v-if="!destroyStartMenu"
        v-show="showStartMenu"
        :visible="showStartMenu"
        @started="onStartMenuStarted"
      />
      <TopLeftPanel
        v-if="!showStartMenu"
        :music-on="musicOn"
        @back="goBack"
        @open-settings="openSettings"
        @toggle-music="onToggleMusic"
      />
      <Hall
        :music-on="musicOn"
        :paused="
          overlay === 'start' || overlay === 'warehouse' || showGameScene
        "
        @startGame="openOverlay('start')"
        @openWarehouse="openOverlay('warehouse')"
        @openTutorial="openTutorial"
        @openEncyclopedia="openOverlay('encyclopedia')"
        @toggle-music="onToggleMusic"
      />
      <div
        v-if="overlay"
        class="overlay"
        :class="{ 'overlay--warehouse': overlay === 'warehouse' }"
      >
        <template v-if="overlay === 'warehouse'">
          <div style="position: relative; width: 100%; height: 100%">
            <TopLeftPanel
              :music-on="musicOn"
              @back="goBack"
              @open-settings="openSettings"
              @toggle-music="onToggleMusic"
            />
            <Warehouse ref="warehouseRef" :music-on="musicOn" />
          </div>
        </template>
        <template v-else-if="overlay === 'start'">
          <StartGame
            :music-on="musicOn"
            :paused="showGameScene"
            @close="closeOverlay"
            @confirm="handleGameStart"
          />
        </template>
        <template v-else>
          <div class="modal">
            <h2 class="modal-title">
              {{
                overlay === 'warehouse'
                  ? '铜偶仓库 · Copper Warehouse'
                  : overlay === 'tutorial'
                    ? '新手教程 · Tutorial'
                    : overlay === 'encyclopedia'
                      ? '游戏百科 · Game Encyclopedia'
                      : '开始游戏 · Start Game'
              }}
            </h2>
            <p class="modal-body">占位内容（后续替换为实际功能界面）。</p>
            <button class="close-btn" @click="closeOverlay">关闭</button>
          </div>
        </template>
      </div>
    </template>
    <!-- 独立设置浮层，覆盖在所有内容之上 -->
    <div
      v-if="showSettingsOverlay"
      class="overlay"
      style="
        z-index: 30000;
        align-items: flex-start;
        justify-content: flex-start;
        background: rgba(0, 0, 0, 0.25);
      "
    >
      <div class="settings">
        <div class="settings__header">
          <div class="settings__title">设置</div>
          <button
            class="settings__close"
            @click="closeSettings"
            aria-label="关闭"
          >
            <img :src="getAssetUrl('@assets/ui/close.png')" alt="关闭" />
          </button>
        </div>
        <div class="settings__content">
          <!-- 控制模式设置 -->
          <div class="settings__section">
            <div class="settings__section-title">视角控制模式</div>
            <div class="settings__control-options">
              <button
                class="settings__control-btn"
                :class="{ active: controlMode === 'touchpad' }"
                @click="setControlMode('touchpad')"
              >
                <span class="control-title">触控板模式（推荐）</span>
                <span class="control-desc">按住拖动视角</span>
              </button>
              <button
                class="settings__control-btn"
                :class="{ active: controlMode === 'mouse' }"
                @click="setControlMode('mouse')"
              >
                <span class="control-title">鼠标模式（实验性）</span>
                <span class="control-desc">直接转动视角</span>
              </button>
            </div>
          </div>
          <button class="settings__item" @click="onDownloadSave">
            <span class="settings__icon">
              <svg
                width="44"
                height="44"
                viewBox="0 0 24 24"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M12 3v12m0 0l-4-4m4 4l4-4"
                  stroke="#fff"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
                <path
                  d="M4 19h16"
                  stroke="#fff"
                  stroke-width="2"
                  stroke-linecap="round"
                />
              </svg>
            </span>
            <span class="settings__label">下载存档</span>
          </button>
          <button class="settings__item" @click="onUploadSave">
            <span class="settings__icon">
              <svg
                width="44"
                height="44"
                viewBox="0 0 24 24"
                fill="none"
                xmlns="http://www.w3.org/2000/svg"
              >
                <path
                  d="M12 21V9m0 0l4 4m-4-4L8 13"
                  stroke="#fff"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
                <path
                  d="M4 5h16"
                  stroke="#fff"
                  stroke-width="2"
                  stroke-linecap="round"
                />
              </svg>
            </span>
            <span class="settings__label">上传存档</span>
          </button>
          <input
            ref="fileInput"
            type="file"
            accept=".json"
            @change="onFileChange"
            style="display: none"
          />
        </div>
      </div>
    </div>
  </div>
</template>