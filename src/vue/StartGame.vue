<script setup>
import { ref, onMounted, onBeforeUnmount, computed, watch } from 'vue';
import { get_copper_list, eventloop } from '../glue.js';
import { getAssetUrl } from '../utils/resourceLoader.js';
import modelCache from '../utils/modelCache.js';
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import './StartGame.css';
const emit = defineEmits(['confirm', 'close']);
const props = defineProps({
  musicOn: {
    type: Boolean,
    default: true,
  },
  paused: {
    type: Boolean,
    default: false,
  },
});
const loading = ref(true);
const error = ref('');
const copperList = ref([]);
const selectedIds = ref(new Set());
const previewContainer = ref(null);
const audioRef = ref(null);
const musicUrl = getAssetUrl('@assets/frontend_resource/startgame.mp3');
let scene, camera, renderer, controls;
let gltfLoader;
const loadedModels = new Map();
const canConfirm = computed(() => selectedIds.value.size === 3);
const selectedCoppers = computed(() => {
  return copperList.value.filter(c => selectedIds.value.has(c.id));
});
function init3DScene() {
  if (!previewContainer.value) return;
  scene = new THREE.Scene();
  scene.background = new THREE.Color(0x1a1a1a);
  camera = new THREE.PerspectiveCamera(
    45,
    previewContainer.value.clientWidth / previewContainer.value.clientHeight,
    0.1,
    100
  );
  camera.position.set(0, 3, 8);
  renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setSize(
    previewContainer.value.clientWidth,
    previewContainer.value.clientHeight
  );
  renderer.setPixelRatio(window.devicePixelRatio);
  previewContainer.value.appendChild(renderer.domElement);
  controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.dampingFactor = 0.05;
  controls.target.set(0, 1, 0);
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
  scene.add(ambientLight);
  const mainLight = new THREE.DirectionalLight(0xffffff, 1.0);
  mainLight.position.set(0, 5, 10);
  scene.add(mainLight);
  const sideLight1 = new THREE.DirectionalLight(0xaaccff, 0.4);
  sideLight1.position.set(-5, 3, 5);
  scene.add(sideLight1);
  const sideLight2 = new THREE.DirectionalLight(0xffccaa, 0.4);
  sideLight2.position.set(5, 3, 5);
  scene.add(sideLight2);
  const backLight = new THREE.DirectionalLight(0xffffff, 0.3);
  backLight.position.set(0, 5, -5);
  scene.add(backLight);
  const floorGeometry = new THREE.PlaneGeometry(20, 20);
  const floorMaterial = new THREE.MeshStandardMaterial({
    color: 0x2a2a2a,
    side: THREE.DoubleSide,
  });
  const floor = new THREE.Mesh(floorGeometry, floorMaterial);
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = 0;
  scene.add(floor);
  gltfLoader = new GLTFLoader();
  const dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath(
    'https://www.gstatic.com/draco/versioned/decoders/1.5.6/'
  );
  gltfLoader.setDRACOLoader(dracoLoader);
  animate3D();
  window.addEventListener('resize', onWindowResize);
}
function animate3D() {
  requestAnimationFrame(animate3D);
  if (controls) controls.update();
  if (renderer && scene && camera) {
    renderer.render(scene, camera);
  }
}
function onWindowResize() {
  if (!previewContainer.value || !camera || !renderer) return;
  camera.aspect =
    previewContainer.value.clientWidth / previewContainer.value.clientHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(
    previewContainer.value.clientWidth,
    previewContainer.value.clientHeight
  );
}
function toggleSelect(id) {
  const set = selectedIds.value;
  if (set.has(id)) {
    set.delete(id);
  } else {
    if (set.size >= 3) return;
    set.add(id);
  }
  selectedIds.value = new Set(set);
}
async function loadCopperModel(copper, index) {
  if (!scene || !gltfLoader) return;
  let modelUrl = copper.modelUrl;
  try {
    const modelInstance = await modelCache.loadModel(modelUrl, true);
    const box = new THREE.Box3().setFromObject(modelInstance);
    const size = box.getSize(new THREE.Vector3());
    const group = new THREE.Group();
    group.add(modelInstance);
    const spacing = 2.5;
    const startX = (-(selectedCoppers.value.length - 1) * spacing) / 2;
    group.position.set(startX + index * spacing, 0, 0);
    group.scale.set(1.0, 1.0, 1.0);
    group.rotation.y = -Math.PI / 2;
    const scaledBox = new THREE.Box3().setFromObject(group);
    group.position.y = -scaledBox.min.y;
    scene.add(group);
    loadedModels.set(copper.id, group);
  } catch (e) {
    createPlaceholderCube(copper, index);
  }
}
function createPlaceholderCube(copper, index) {
  if (!scene) return;
  const geometry = new THREE.BoxGeometry(0.8, 0.8, 0.8);
  const material = new THREE.MeshStandardMaterial({ color: 0x4488ff });
  const cube = new THREE.Mesh(geometry, material);
  const spacing = 2.5;
  const startX = (-(selectedCoppers.value.length - 1) * spacing) / 2;
  cube.position.set(startX + index * spacing, 0.8, 0);
  cube.rotation.y = -Math.PI / 2;
  scene.add(cube);
  loadedModels.set(copper.id, cube);
}
function updateModels() {
  if (!scene) return;
  loadedModels.forEach(obj => {
    scene.remove(obj);
    if (obj.geometry) obj.geometry.dispose();
    if (obj.material) {
      if (Array.isArray(obj.material)) {
        obj.material.forEach(m => m.dispose());
      } else {
        obj.material.dispose();
      }
    }
  });
  loadedModels.clear();
  selectedCoppers.value.forEach((copper, index) => {
    loadCopperModel(copper, index);
  });
}
async function loadCoppers() {
  loading.value = true;
  error.value = '';
  try {
    const plain = get_copper_list();
    const arr = Array.isArray(plain?.coppers) ? plain.coppers : [];
    copperList.value = (arr || []).map((c, i) => {
      const modelUrl = c?.copper_info?.model_url;
      return {
        id: Number(c?.id ?? i + 1),
        name: c?.copper_info?.name || `铜偶#${i + 1}`,
        icon: getAssetUrl(c?.copper_info?.icon_url || ''),
        level: Number(c?.level ?? 1),
        copperType: c?.copper_type || 'Arcanist',
        modelName: c?.copper_info?.name?.toLowerCase() || '',
        modelUrl: modelUrl ? getAssetUrl(modelUrl) : '',
      };
    });
  } catch (e) {
    error.value = '加载失败，请重试';
  } finally {
    loading.value = false;
  }
}
async function startGame() {
  if (selectedIds.value.size !== 3) return;
  const ids = Array.from(selectedIds.value).map(id => String(id));
  window.__ACTUAL_COPPER_IDS__ = ids;
  emit('confirm', { ids });
}
function close() {
  emit('close');
}
watch(
  selectedCoppers,
  () => {
    updateModels();
  },
  { deep: true }
);
onMounted(() => {
  loadCoppers();
  setTimeout(() => {
    init3DScene();
  }, 100);
  if (props.musicOn && !props.paused && audioRef.value) {
    const tryPlay = () => {
      const audioEl = audioRef.value;
      if (!audioEl) return;
      if (audioEl.readyState >= 2) {
        audioEl
          .play()
          .then(() => {
          })
          .catch(err => {
          });
      } else {
        const onCanPlay = () => {
          const el = audioRef.value;
          if (!el) return;
          el.play()
            .then(() => {
            })
            .catch(err => {
            });
          el.removeEventListener('canplay', onCanPlay);
        };
        audioEl.addEventListener('canplay', onCanPlay, { once: true });
      }
    };
    setTimeout(tryPlay, 200);
  }
});
watch(
  () => props.musicOn,
  newVal => {
    const audioEl = audioRef.value;
    if (!audioEl) return;
    if (newVal && !props.paused) {
      if (audioEl.readyState >= 2) {
        audioEl.play().catch(err => {
        });
      } else {
        const playWhenReady = () => {
          const el = audioRef.value;
          if (!el) return;
          el.play().catch(err => {
          });
          el.removeEventListener('canplay', playWhenReady);
        };
        audioEl.addEventListener('canplay', playWhenReady);
      }
    } else {
      audioEl.pause();
    }
  }
);
watch(
  () => props.paused,
  newVal => {
    const audioEl = audioRef.value;
    if (!audioEl) return;
    if (newVal) {
      audioEl.pause();
    } else if (props.musicOn) {
      if (audioEl.readyState >= 2) {
        audioEl.play().catch(err => {
        });
      } else {
        const playWhenReady = () => {
          const el = audioRef.value;
          if (!el) return;
          el.play().catch(err => {
          });
          el.removeEventListener('canplay', playWhenReady);
        };
        audioEl.addEventListener('canplay', playWhenReady);
      }
    }
  }
);
onBeforeUnmount(() => {
  window.removeEventListener('resize', onWindowResize);
  if (audioRef.value) {
    audioRef.value.pause();
  }
  loadedModels.forEach(obj => {
    if (scene) scene.remove(obj);
  });
  loadedModels.clear();
  if (renderer) {
    renderer.dispose();
  }
  if (controls) {
    controls.dispose();
  }
});
const panel1Src = `url('${getAssetUrl('@assets/ui/panel1.png')}')`;
const panel2Src = `url('${getAssetUrl('@assets/ui/panel2.png')}')`;
const panel3Src = `url('${getAssetUrl('@assets/ui/panel3.png')}')`;
const panel6Src = `url('${getAssetUrl('@assets/ui/panel6.png')}')`;
const panel7Src = `url('${getAssetUrl('@assets/ui/panel7.png')}')`;
const panel8Src = `url('${getAssetUrl('@assets/ui/panel8.png')}')`;
const panel9Src = `url('${getAssetUrl('@assets/ui/panel9.png')}')`;
const panel10Src = `url('${getAssetUrl('@assets/ui/panel10.png')}')`;
</script>
<template>
  <div class="startgame-modal">
    <div class="card">
      <div class="card__header">
        <div class="card__title">开始游戏</div>
        <button class="card__close" @click="close" aria-label="关闭">
          <img :src="getAssetUrl('@assets/ui/close.png')" alt="关闭" />
        </button>
      </div>
      <div class="card__body">
        <div class="card__content">
          <div v-if="loading" class="loading">加载中...</div>
          <div v-else-if="error" class="error">{{ error }}</div>
          <div v-else class="list">
            <div
              v-for="c in copperList"
              :key="c.id"
              class="item"
              :class="{ 'item--selected': selectedIds.has(c.id) }"
              @click="toggleSelect(c.id)"
            >
              <div class="item__img">
                <img :src="c.icon" :alt="c.name" />
              </div>
              <div class="item__meta">
                <div class="item__name">{{ c.name }}</div>
                <div class="item__level">Lv. {{ c.level }}</div>
              </div>
            </div>
          </div>
          <div class="hint">从仓库中选择3个铜偶开始游戏。</div>
        </div>
        <div class="preview">
          <div class="preview__title">队伍预览</div>
          <div ref="previewContainer" class="preview__scene"></div>
          <div class="preview__info">
            <div v-if="selectedCoppers.length === 0" class="preview__empty">
              请选择铜偶
            </div>
            <div v-else class="preview__names">
              <div
                v-for="(copper, index) in selectedCoppers"
                :key="copper.id"
                class="preview__name"
              >
                <span class="preview__name-number">{{ index + 1 }}</span>
                <span class="preview__name-text">{{ copper.name }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="card__footer">
        <button
          class="btn btn--primary"
          :disabled="!canConfirm"
          @click="startGame"
        >
          开始
        </button>
        <button class="btn" @click="close">返回</button>
      </div>
    </div>
    <audio ref="audioRef" :src="musicUrl" loop preload="auto"></audio>
  </div>
</template>
<style scoped>
.card {
  border-image-source: v-bind(panel1Src);
}
.card__header {
  border-image-source: v-bind(panel3Src);
}
.preview {
  border-image-source: v-bind(panel9Src);
}
.preview__name {
  border-image-source: v-bind(panel10Src);
}
.item {
  border-image-source: v-bind(panel6Src);
}
.item--selected {
  border-image-source: v-bind(panel8Src);
}
.card__footer {
  border-image-source: v-bind(panel2Src);
}
.btn {
  border-image-source: v-bind(panel8Src);
}
.btn--primary {
  border-image-source: v-bind(panel7Src);
}
</style>