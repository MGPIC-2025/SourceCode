<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue';
import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/examples/jsm/loaders/DRACOLoader.js';
import modelCache from '../utils/modelCache.js';
import './PuppetModelView.css';
const props = defineProps({
  puppet: { type: Object, default: null },
});
const mountEl = ref(null);
const isLoading = ref(false);
let renderer = null;
let scene = null;
let camera = null;
let animationId = 0;
let currentModel = null;
let currentMixer = null;
let clock = new THREE.Clock();
let resizeObserver = null;
let dracoLoader = null;
let loadSequence = 0;
let isInitialized = false;
if (!window.__GLTF_MEMORY_CACHE__) {
  window.__GLTF_MEMORY_CACHE__ = new Map();
}
const gltfMemoryCache = window.__GLTF_MEMORY_CACHE__;
function initThreeIfNeeded() {
  if (isInitialized) return;
  const container = mountEl.value;
  if (!container) {
    return;
  }
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(45, 1, 0.1, 1000);
  camera.position.set(0, 1, 3);
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(window.devicePixelRatio || 1);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath(
    'https://www.gstatic.com/draco/versioned/decoders/1.5.6/'
  );
  dracoLoader.setCrossOrigin('anonymous');
  container.innerHTML = '';
  container.appendChild(renderer.domElement);
  const ambient = new THREE.AmbientLight(0xffffff, 1.2);
  const dir = new THREE.DirectionalLight(0xffffff, 1.5);
  dir.position.set(3, 5, 2);
  const dir2 = new THREE.DirectionalLight(0xffffff, 0.8);
  dir2.position.set(-2, 3, 4);
  const pointLight = new THREE.PointLight(0xffffff, 1.0, 10);
  pointLight.position.set(0, 2, 3);
  scene.add(ambient, dir, dir2, pointLight);
  const onResize = () => {
    if (!container || !renderer) return;
    let w = container.clientWidth;
    let h = container.clientHeight;
    if (!w || !h) {
      const rect = container.getBoundingClientRect();
      w = rect.width || 200;
      h = rect.height || 200;
      if (!rect.width || !rect.height) {
        requestAnimationFrame(onResize);
        return;
      }
    }
    renderer.setSize(w, h, true);
    camera.aspect = w / Math.max(1, h);
    camera.updateProjectionMatrix();
  };
  onResize();
  resizeObserver = new ResizeObserver(onResize);
  resizeObserver.observe(container);
  requestAnimationFrame(() => {
    onResize();
    requestAnimationFrame(() => {
      onResize();
      requestAnimationFrame(onResize);
    });
  });
  const animate = () => {
    if (!renderer || !scene || !camera) return;
    animationId = requestAnimationFrame(animate);
    const delta = clock.getDelta();
    if (currentMixer) currentMixer.update(delta);
    if (currentModel) currentModel.rotation.y += delta * 0.6;
    renderer.render(scene, camera);
  };
  animate();
  isInitialized = true;
}
function clearCurrentModel() {
  if (currentMixer) {
    currentMixer.stopAllAction();
    currentMixer = null;
  }
  if (currentModel) {
    scene.remove(currentModel);
    currentModel.traverse(obj => {
      if (obj.isMesh) {
        if (obj.geometry) obj.geometry.dispose();
        if (Array.isArray(obj.material)) {
          obj.material.forEach(m => {
            if (m.map) m.map.dispose();
            if (m) m.dispose && m.dispose();
          });
        } else if (obj.material) {
          if (obj.material.map) obj.material.map.dispose();
          if (obj.material.dispose) obj.material.dispose();
        }
      }
    });
    currentModel = null;
  }
}
function fitCameraToObject(object) {
  const box = new THREE.Box3().setFromObject(object);
  const size = new THREE.Vector3();
  const center = new THREE.Vector3();
  box.getSize(size);
  box.getCenter(center);
  object.position.sub(center);
  object.position.add(new THREE.Vector3(0, 0, 0));
  const shrink = 0.8;
  object.scale.multiplyScalar(shrink);
  const canvas = renderer?.domElement;
  const w = canvas ? canvas.clientWidth || canvas.width : 200;
  const h = canvas ? canvas.clientHeight || canvas.height : 200;
  const aspect = Math.max(1e-6, w / Math.max(1, h));
  const vFov = camera.fov * (Math.PI / 180);
  const hFov = 2 * Math.atan(Math.tan(vFov / 2) * aspect);
  const padding = 1.05;
  const distV = size.y / 2 / Math.tan(vFov / 2);
  const distH = size.x / 2 / Math.tan(hFov / 2);
  const dist = padding * Math.max(distV, distH, 0.1);
  camera.position.set(0, 0, dist);
  camera.lookAt(0, 0, 0);
}
async function loadPuppetModel(puppet) {
  if (!puppet) return;
  isLoading.value = true;
  initThreeIfNeeded();
  clearCurrentModel();
  const token = ++loadSequence;
  let modelUrl = puppet.modelUrl || '';
  if (!modelUrl || modelUrl.trim() === '') {
    return;
  }
  try {
    const modelInstance = await modelCache.loadModel(modelUrl);
    if (token !== loadSequence) {
      if (gltf && gltf.scene) {
        gltf.scene.traverse(obj => {
          if (obj.isMesh) {
            if (obj.geometry) obj.geometry.dispose();
            if (Array.isArray(obj.material)) {
              obj.material.forEach(m => {
                if (m.map) m.map.dispose();
                if (m.dispose) m.dispose();
              });
            } else if (obj.material) {
              if (obj.material.map) obj.material.map.dispose();
              if (obj.material.dispose) obj.material.dispose();
            }
          }
        });
      }
      return;
    }
    if (!scene) {
      initThreeIfNeeded();
      let waitCount = 0;
      while (!scene && waitCount < 40) {
        await new Promise(resolve => setTimeout(resolve, 50));
        waitCount++;
      }
      if (!scene) {
        return;
      }
    }
    currentModel = modelInstance;
    if (!currentModel) {
      return;
    }
    scene.add(currentModel);
    fitCameraToObject(currentModel);
    isLoading.value = false;
  } catch (e) {
    if (typeof e?.message === 'string' && e.message.includes('DRACOLoader')) {
      try {
        const fallbackLoader = new GLTFLoader();
        fallbackLoader.setCrossOrigin('anonymous');
        const fallbackGltf = await fallbackLoader.loadAsync(modelUrl);
        if (token === loadSequence) {
          currentModel = fallbackGltf.scene || fallbackGltf.scenes?.[0];
          if (currentModel) {
            scene.add(currentModel);
            if (fallbackGltf.animations && fallbackGltf.animations.length) {
              currentMixer = new THREE.AnimationMixer(currentModel);
              const action = currentMixer.clipAction(
                fallbackGltf.animations[0]
              );
              action.play();
            }
            fitCameraToObject(currentModel);
            return;
          }
        }
      } catch (fallbackError) {
      }
    }
    if (token === loadSequence) {
      const geo = new THREE.BoxGeometry(1, 1, 1);
      const mat = new THREE.MeshStandardMaterial({ color: 0x8888ff });
      currentModel = new THREE.Mesh(geo, mat);
      scene.add(currentModel);
      fitCameraToObject(currentModel);
    }
    isLoading.value = false;
  }
}
watch(
  () => props.puppet,
  async val => {
    await nextTick();
    loadPuppetModel(val);
  },
  { immediate: false }
);
onMounted(() => {
  nextTick(() => {
    if (mountEl.value) {
      initThreeIfNeeded();
      if (props.puppet) {
        setTimeout(() => {
          loadPuppetModel(props.puppet);
        }, 0);
      }
    }
  });
});
onBeforeUnmount(() => {
  cancelAnimationFrame(animationId);
  clearCurrentModel();
  if (resizeObserver && mountEl.value) {
    try {
      resizeObserver.unobserve(mountEl.value);
    } catch (_) {}
  }
  const sceneToClean = scene;
  const rendererToClean = renderer;
  renderer = null;
  scene = null;
  camera = null;
  isInitialized = false;
  loadSequence = 0;
  const deferredCleanup = () => {
    if (sceneToClean) {
      sceneToClean.traverse(obj => {
        if (obj.isMesh) {
          try {
            if (obj.geometry) obj.geometry.dispose();
            if (Array.isArray(obj.material)) {
              obj.material.forEach(m => {
                try {
                  if (m.map) m.map.dispose();
                  if (m.dispose) m.dispose();
                } catch (_) {}
              });
            } else if (obj.material) {
              try {
                if (obj.material.map) obj.material.map.dispose();
                if (obj.material.dispose) obj.material.dispose();
              } catch (_) {}
            }
          } catch (_) {}
        }
      });
    }
    if (rendererToClean) {
      try {
        rendererToClean.dispose();
        rendererToClean.forceContextLoss && rendererToClean.forceContextLoss();
      } catch (_) {}
    }
  };
  if (typeof window !== 'undefined' && window.requestIdleCallback) {
    window.requestIdleCallback(deferredCleanup, { timeout: 1000 });
  } else {
    setTimeout(deferredCleanup, 100);
  }
});
</script>
<template>
  <div class="model-wrapper">
    <div ref="mountEl" class="model-canvas"></div>
    <div v-if="isLoading" class="model-loading">
      <div class="loading-spinner"></div>
    </div>
  </div>
</template>