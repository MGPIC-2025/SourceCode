<script setup>
import { onMounted, onBeforeUnmount, ref, watch } from 'vue';
import * as THREE from 'three';
import {
  getAssetUrl,
  precacheAllResources,
  getCacheStatus,
} from '../utils/resourceLoader.js';
import modelPreloadManager from '../utils/modelPreloadManager.js';
import { modelCache } from '../utils/modelCache.js';
import { getSettings, updateSetting } from '../utils/gameSettings.js';
import './StartMenu.css';
const props = defineProps({
  visible: {
    type: Boolean,
    default: true,
  },
});
const canvasRef = ref(null);
let scene = null;
let camera = null;
let renderer = null;
let animationId = null;
let logoObject = null;
let baseScale = 1.2;
const isReady = ref(false);
const showButtons = ref(false);
const showSettings = ref(false);
const controlMode = ref('touchpad');
const isElectron = ref(false);
const startBg = ref(
  getAssetUrl('ui/Gemini_Generated_Image_gtrehogtrehogtre (1).png')
);
const panel5Src = `url('${getAssetUrl('@assets/ui/panel4.png')}')`;
const emit = defineEmits(['started']);
watch(
  () => props.visible,
  visible => {
    if (visible && scene && logoObject) {
      resume();
    } else if (!visible) {
      pause();
    }
  }
);
function renderLoop() {
  animationId = requestAnimationFrame(renderLoop);
  if (logoObject) {
    const time = Date.now() * 0.001;
    logoObject.position.y = Math.sin(time * 0.8) * 0.1;
    logoObject.rotation.y = Math.sin(time * 0.6) * 0.1;
    const scale = baseScale + Math.sin(time * 1.2) * 0.04;
    logoObject.scale.setScalar(scale);
  }
  renderer && renderer.render(scene, camera);
}
function handleResize() {
  if (!renderer || !camera) return;
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}
function pause() {
  if (animationId) {
    cancelAnimationFrame(animationId);
    animationId = null;
  }
  if (renderer) {
    renderer.setAnimationLoop(null);
  }
}
function resume() {
  if (!animationId) {
    renderLoop();
  }
}
function destroyScene() {
  try {
    pause();
  } catch (_) {}
  try {
    window.removeEventListener('resize', handleResize);
  } catch (_) {}
  try {
    if (scene) {
      scene.traverse(obj => {
        if (obj.isMesh) {
          if (obj.geometry && obj.geometry.dispose) obj.geometry.dispose();
          const mat = obj.material;
          if (Array.isArray(mat)) {
            mat.forEach(m => m && m.dispose && m.dispose());
          } else if (mat && mat.dispose) {
            mat.dispose();
          }
        }
      });
      scene.clear();
    }
  } catch (_) {}
  try {
    if (renderer) {
      renderer.clear(true, true, true);
      renderer.dispose();
      const gl = renderer.getContext && renderer.getContext();
      const lose =
        gl && gl.getExtension && gl.getExtension('WEBGL_lose_context');
      if (lose && lose.loseContext) lose.loseContext();
    }
  } catch (_) {}
  scene = null;
  camera = null;
  renderer = null;
  logoObject = null;
}
async function initScene(onProgress = null) {
  try {
    window.getAssetUrl = getAssetUrl;
    window.precacheAllResources = precacheAllResources;
    window.getCacheStatus = getCacheStatus;
  } catch (_) {}
  if (!scene || !renderer) {
    return;
  }
  if (onProgress) onProgress(0, 100, 20);
  const hasLight = scene.children.some(child => child.isLight);
  if (!hasLight) {
    const ambientLight = new THREE.AmbientLight(0x404040, 0.4);
    scene.add(ambientLight);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 12.5);
    directionalLight.position.set(-5, -2, 1);
    scene.add(directionalLight);
  }
  if (onProgress) onProgress(0, 100, 50);
  const logoUrl = getAssetUrl('logo.glb');
  try {
    if (onProgress) onProgress(0, 100, 60);
    const logoModel = await modelCache.loadModel(logoUrl, true);
    if (onProgress) onProgress(0, 100, 80);
    logoModel.position.set(0, 0, 0);
    scene.add(logoModel);
    const box = new THREE.Box3().setFromObject(logoModel);
    const center = box.getCenter(new THREE.Vector3());
    logoModel.position.set(-center.x, -center.y, -center.z - 0.3);
    try {
      logoModel.scale.setScalar(baseScale);
    } catch (_) {}
    logoObject = logoModel;
    if (onProgress) onProgress(0, 100, 80);
    try {
      await modelPreloadManager.startPreload(
        ['high', 'medium'],
        (loaded, total, percentage) => {
          const mappedProgress = 80 + percentage * 0.15;
          if (onProgress) onProgress(0, 100, Math.round(mappedProgress));
        }
      );
    } catch (err) {
    }
    if (onProgress) onProgress(0, 100, 100);
    isReady.value = true;
    showButtons.value = true;
  } catch (e) {
    const geometry = new THREE.BoxGeometry(1, 1, 1);
    const material = new THREE.MeshBasicMaterial({ color: 0xf59e0b });
    const placeholder = new THREE.Mesh(geometry, material);
    scene.add(placeholder);
    logoObject = placeholder;
    try {
      await modelPreloadManager.startPreload(
        ['high', 'medium'],
        (loaded, total, percentage) => {
          const mappedProgress = 80 + percentage * 0.15;
          if (onProgress) onProgress(0, 100, Math.round(mappedProgress));
        }
      );
    } catch (err) {
    }
    if (onProgress) onProgress(0, 100, 100);
    isReady.value = true;
    showButtons.value = true;
  }
  window.__START_MENU_PAUSE__ = () => pause();
  window.__START_MENU_RESUME__ = () => resume();
}
function onStart() {
  emit('started');
  pause();
}
function onOpenSettings() {
  const settings = getSettings();
  controlMode.value = settings.controlMode;
  showSettings.value = true;
}
function onCloseSettings() {
  showSettings.value = false;
}
function setControlMode(mode) {
  controlMode.value = mode;
  updateSetting('controlMode', mode);
  if (window.updateControlMode) {
    window.updateControlMode(mode);
  }
}
onMounted(() => {
  showButtons.value = false;
  isReady.value = false;
  isElectron.value =
    typeof window !== 'undefined' &&
    (window.navigator.userAgent.toLowerCase().includes('electron') ||
      window.process?.type === 'renderer' ||
      !!(
        window.require &&
        window.process &&
        window.process.versions &&
        window.process.versions.electron
      ));
  if (!scene && canvasRef.value) {
    scene = new THREE.Scene();
    scene.background = null;
    camera = new THREE.PerspectiveCamera(
      50,
      window.innerWidth / window.innerHeight,
      0.1,
      1000
    );
    camera.position.set(-3.655, 0.2, -0.006);
    camera.rotation.set(-1.618275, -1.538307, -1.6183, 'XYZ');
    renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      canvas: canvasRef.value,
    });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setClearColor(0x000000, 0);
    window.addEventListener('resize', handleResize);
    renderLoop();
  } else if (scene && !logoObject) {
  } else if (logoObject) {
    showButtons.value = true;
    isReady.value = true;
  }
  window.__INIT_THREE_SCENE__ = async onProgress => {
    if (scene && logoObject) {
      showButtons.value = true;
      isReady.value = true;
      return;
    }
    await initScene(onProgress);
  };
});
onBeforeUnmount(() => {
  destroyScene();
});
</script>
<template>
  <div class="startmenu">
    <div v-if="!isElectron" class="download-banner">
      <span class="download-banner__text">
        想要获得帧率更高的游戏体验，请下载本地版本
      </span>
      <a
        href="https://github.com/MGPIC-2025/Cross/releases"
        target="_blank"
        rel="noopener noreferrer"
        class="download-banner__link"
      >
        点击下载
      </a>
    </div>
    <div
      class="startmenu__bg"
      :style="{ backgroundImage: `url('${startBg}')` }"
    />
    <canvas ref="canvasRef" class="startmenu__canvas" />
    <div
      class="startmenu-ui"
      v-show="showButtons"
      :class="{ 'fade-in': showButtons }"
    >
      <button
        id="start-btn"
        class="startmenu-btn"
        aria-label="开始"
        @click="onStart"
      >
        开始
      </button>
      <button
        id="settings-btn"
        class="startmenu-btn"
        aria-label="设置"
        @click="onOpenSettings"
      >
        设置
      </button>
    </div>
    <div v-if="showSettings" class="settings-local">
      <div class="settings-local__card">
        <div class="settings-local__header">
          <div class="settings-local__title">设置</div>
          <button
            class="settings-local__close"
            @click="onCloseSettings"
            aria-label="关闭"
          >
            ✕
          </button>
        </div>
        <div class="settings-local__content">
          <div class="settings-local__row">
            <div class="setting-label">视角控制模式</div>
            <div class="setting-options">
              <button
                class="option-btn"
                :class="{ active: controlMode === 'touchpad' }"
                @click="setControlMode('touchpad')"
              >
                <span class="option-title">触控板模式</span>
                <span class="option-desc">需要按住鼠标拖动</span>
              </button>
              <button
                class="option-btn"
                :class="{ active: controlMode === 'mouse' }"
                @click="setControlMode('mouse')"
              >
                <span class="option-title">鼠标模式</span>
                <span class="option-desc">直接移动鼠标转动视角</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<style scoped>
.startmenu-btn {
  border-image-source: v-bind(panel5Src);
}
</style>