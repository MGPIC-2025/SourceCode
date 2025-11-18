<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { messageQueue, eventloop } from '../glue.js';
import {
  getAssetUrl,
  getCopperModelUrl,
  getEnemyModelUrl,
  getStructureModelUrl,
  getMaterialModelUrl,
} from '../utils/resourceLoader.js';
import modelCache from '../utils/modelCache.js';
import {
  getCopperEnglishName,
  getCopperTypeFolder,
  getStructureEnglishName,
} from '../utils/mappings.js';
import { getSetting } from '../utils/gameSettings.js';
import { onEvent, offEvent, emitEvent, EventTypes } from '../utils/eventBus.js';
import { useHealthBars } from '../composables/useHealthBars.js';
import { useIndicators } from '../composables/useIndicators.js';
import { useEffects } from '../composables/useEffects.js';
import {
  getControlConfig,
  getSkyboxConfig,
  getLightingConfig,
  getGridCellMaterialConfig,
  getMusicUrl,
  getSoundUrl,
} from '../utils/sceneConfig.js';
import {
  loadSkybox,
  applyLighting,
  createCamera,
  createRenderer,
  createGLTFLoader,
  createTestUnits,
  createFloor,
  disposeSkybox,
} from '../utils/sceneUtils.js';
import ActionPanel from './ActionPanel.vue';
import TurnSystem from './ActionPanelParts/TurnSystem.vue';
import SummonModal from './ActionPanelParts/SummonModal.vue';
import StructurePanel from './StructurePanel.vue';
import ResourcePanel from './ResourcePanel.vue';
const props = defineProps({
  isGameMode: {
    type: Boolean,
    default: false,
  },
  musicOn: {
    type: Boolean,
    default: true,
  },
});
const container = ref(null);
const emit = defineEmits(['back']);
const audioRef = ref(null);
const musicUrl = getMusicUrl('gameScene');
const moveSoundRef = ref(null);
const moveEnemySoundRef = ref(null);
const attackSoundRef = ref(null);
const attackEnemySoundRef = ref(null);
const meHurtSoundRef = ref(null);
const enemyHurtSoundRef = ref(null);
const moveSoundUrl = getSoundUrl('move');
const moveEnemySoundUrl = getSoundUrl('moveEnemy');
const attackSoundUrl = getSoundUrl('attack');
const attackEnemySoundUrl = getSoundUrl('attackEnemy');
const meHurtSoundUrl = getSoundUrl('meHurt');
const enemyHurtSoundUrl = getSoundUrl('enemyHurt');
let scene, camera, renderer, controls;
let models = [];
const controlCfgForFocus = getControlConfig();
let focusState = {
  focusPosition: null,
  focusTarget: null,
  lerpFactor: controlCfgForFocus.focusLerpFactor,
};
let raycaster = null;
let mouse = new THREE.Vector2();
let gltfLoader = null;
let healthBarsManager = null;
let indicatorsManager = null;
let effectsManager = null;
const previousHealth = new Map();
const keys = {
  w: false,
  a: false,
  s: false,
  d: false,
  shift: false,
  space: false,
};
const controlCfg = getControlConfig();
const moveSpeed = controlCfg.moveSpeed;
const rotationSpeed = controlCfg.rotationSpeed;
const controlMode = ref(getSetting('controlMode') || 'touchpad');
const mouseSensitivity = ref(getSetting('mouseSensitivity') || 0.002);
window.updateControlMode = mode => {
  controlMode.value = mode;
};
window.updateMouseSensitivity = sensitivity => {
  mouseSensitivity.value = sensitivity;
};
function handleKeyDown(event) {
  const key = event.key.toLowerCase();
  if (key === 'w' || key === 'a' || key === 's' || key === 'd') {
    keys[key] = true;
  } else if (key === 'shift') {
    keys.shift = true;
  } else if (key === ' ') {
    keys.space = true;
    event.preventDefault();
  } else if (key === 'escape') {
    if (document.pointerLockElement) {
      document.exitPointerLock();
    }
  }
}
function handleKeyUp(event) {
  const key = event.key.toLowerCase();
  if (key === 'w' || key === 'a' || key === 's' || key === 'd') {
    keys[key] = false;
  } else if (key === 'shift') {
    keys.shift = false;
  } else if (key === ' ') {
    keys.space = false;
  }
}
let isMouseDown = false;
let lastMouseX = 0;
let lastMouseY = 0;
let pitch = 0;
let yaw = 0;
let isPointerLocked = false;
function handleMouseDown(event) {
  if (event.button !== 0) return;
  if (controlMode.value === 'mouse' && container.value) {
    container.value.requestPointerLock();
  }
  isMouseDown = true;
  lastMouseX = event.clientX;
  lastMouseY = event.clientY;
}
function handleMouseUp() {
  isMouseDown = false;
}
function handleMouseMove(event) {
  if (controlMode.value === 'touchpad') {
    if (!isMouseDown) return;
    const deltaX = event.clientX - lastMouseX;
    const deltaY = event.clientY - lastMouseY;
    yaw -= deltaX * mouseSensitivity.value;
    pitch -= deltaY * mouseSensitivity.value;
    lastMouseX = event.clientX;
    lastMouseY = event.clientY;
  } else if (controlMode.value === 'mouse' && isPointerLocked) {
    const deltaX = event.movementX || 0;
    const deltaY = event.movementY || 0;
    yaw -= deltaX * mouseSensitivity.value;
    pitch -= deltaY * mouseSensitivity.value;
  }
  pitch = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, pitch));
  camera.rotation.order = 'YXZ';
  camera.rotation.y = yaw;
  camera.rotation.x = pitch;
}
function handlePointerLockChange() {
  isPointerLocked = document.pointerLockElement === container.value;
  if (isPointerLocked) {
  } else {
  }
}
function handlePointerLockError() {
}
function resetCameraInternal() {
  if (!camera) return;
  camera.position.set(0, 10, 15);
  camera.lookAt(0, 0, 0);
  yaw = camera.rotation.y;
  pitch = camera.rotation.x;
  focusState.focusPosition = null;
  focusState.focusTarget = null;
}
const selectedCopper = ref(null);
const selectedCopperResources = ref([]);
const copperActionPanelRef = ref(null);
const hasAttackTargets = ref(false);
const transferTargetPositions = ref([]);
const transferTargets = ref([]);
const selectedStructure = ref(null);
const selectedStructureData = ref(null);
const showSummonModal = ref(false);
const summonPosition = ref(null);
const enemyList = ref([]);
const currentBuildingName = ref(null);
const currentRound = ref(1);
const playerCoppers = ref([]);
const currentCopperIndex = ref(-1);
const currentActionMode = ref(null);
const isEnemyMoving = ref(false);
const pendingEnemyMoves = ref(new Set());
const isMoveLocked = ref(false);
const copperCanBuildMap = new Map();
const showGameOverDialog = ref(false);
const showGameSuccessDialog = ref(false);
const showCredits = ref(false);
const showWithdrawDialog = ref(false);
const showResourceDialog = ref(false);
const resourceDialogMessage = ref('');
const currentCopperId = computed(() => {
  if (
    playerCoppers.value.length === 0 ||
    currentCopperIndex.value < 0 ||
    currentCopperIndex.value >= playerCoppers.value.length
  ) {
    return null;
  }
  const copper = playerCoppers.value[currentCopperIndex.value];
  return copper ? copper.id : null;
});
onMounted(async () => {
  initScene();
  if (props.isGameMode) {
    resetCameraInternal();
  }
  setupMessageQueue();
  if (messageQueue.sceneContext?.setTestMode) {
    messageQueue.sceneContext.setTestMode('eventloop');
  }
  if (window.__ACTUAL_COPPER_IDS__) {
    const ids = window.__ACTUAL_COPPER_IDS__;
    const message = JSON.stringify({ type: 'on_game_start', content: { ids } });
    eventloop(message);
    delete window.__ACTUAL_COPPER_IDS__;
  } else {
  }
  window.addEventListener('keydown', handleKeyDown);
  window.addEventListener('keyup', handleKeyUp);
  window.addEventListener('mousedown', handleMouseDown);
  window.addEventListener('mouseup', handleMouseUp);
  window.addEventListener('mousemove', handleMouseMove);
  document.addEventListener('pointerlockchange', handlePointerLockChange);
  document.addEventListener('pointerlockerror', handlePointerLockError);
  animate();
  if (import.meta.env.DEV) {
    window.setCameraFocus = (distance = 8, height = 6) => {
      window.cameraFocusDistance = distance;
      window.cameraFocusHeight = height;
    };
    window.resetCamera = resetCameraInternal;
    window.toggleAutoFocus = () => {
      window.disableAutoFocus = !window.disableAutoFocus;
      if (window.disableAutoFocus) {
        focusState.focusPosition = null;
        focusState.focusTarget = null;
      }
    };
  }
  if (props.musicOn && audioRef.value) {
    const tryPlay = () => {
      if (audioRef.value.readyState >= 2) {
        audioRef.value
          .play()
          .then(() => {
          })
          .catch(err => {
          });
      } else {
        const onCanPlay = () => {
          audioRef.value
            .play()
            .then(() => {
            })
            .catch(err => {
            });
          audioRef.value.removeEventListener('canplay', onCanPlay);
        };
        audioRef.value.addEventListener('canplay', onCanPlay, { once: true });
      }
    };
    setTimeout(tryPlay, 200);
  }
});
watch(
  () => props.musicOn,
  newVal => {
    if (!audioRef.value) return;
    if (newVal) {
      if (audioRef.value.readyState >= 2) {
        audioRef.value.play().catch(err => {
        });
      } else {
        const playWhenReady = () => {
          audioRef.value.play().catch(err => {
          });
          audioRef.value.removeEventListener('canplay', playWhenReady);
        };
        audioRef.value.addEventListener('canplay', playWhenReady);
      }
    } else {
      audioRef.value.pause();
    }
  }
);
onBeforeUnmount(() => {
  window.removeEventListener('resize', onWindowResize);
  window.removeEventListener('click', onSceneClick);
  window.removeEventListener('keydown', handleKeyDown);
  window.removeEventListener('keyup', handleKeyUp);
  window.removeEventListener('mousedown', handleMouseDown);
  window.removeEventListener('mouseup', handleMouseUp);
  window.removeEventListener('mousemove', handleMouseMove);
  document.removeEventListener('pointerlockchange', handlePointerLockChange);
  document.removeEventListener('pointerlockerror', handlePointerLockError);
  if (document.pointerLockElement) {
    document.exitPointerLock();
  }
  if (audioRef.value) {
    audioRef.value.pause();
  }
  if (healthBarsManager) {
    healthBarsManager.dispose();
  }
  if (indicatorsManager) {
    indicatorsManager.dispose();
  }
  if (effectsManager) {
    effectsManager.dispose();
  }
  if (scene) {
    disposeSkybox(scene);
  }
  if (renderer) {
    renderer.dispose();
  }
});
function initScene() {
  scene = new THREE.Scene();
  const skyboxCfg = getSkyboxConfig();
  loadSkybox(scene, skyboxCfg);
  camera = createCamera();
  raycaster = new THREE.Raycaster();
  renderer = createRenderer(container.value);
  controls = null;
  const lightingCfg = getLightingConfig();
  applyLighting(scene, lightingCfg);
  createFloor(scene);
  gltfLoader = createGLTFLoader();
  if (props.isGameMode) {
    window.addEventListener('click', onSceneClick);
  }
  createTestUnits(scene, models);
  healthBarsManager = useHealthBars(scene, camera);
  indicatorsManager = useIndicators(scene);
  effectsManager = useEffects(scene);
  window.addEventListener('resize', onWindowResize);
}
async function loadGLTFModel(copperType, copperName, position, scale = 1.0) {
  const modelUrl = getCopperModelUrl(copperType, copperName);
  try {
    const cachedModel = await modelCache.loadModel(modelUrl, true);
    const modelInstance = cachedModel.clone(true);
    modelInstance.traverse(child => {
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material = child.material.map(mat => mat.clone());
        } else {
          child.material = child.material.clone();
        }
      }
    });
    const box = new THREE.Box3().setFromObject(modelInstance);
    const size = box.getSize(new THREE.Vector3());
    const group = new THREE.Group();
    group.add(modelInstance);
    group.position.set(position[0], 0, position[1]);
    group.scale.set(scale, scale, scale);
    group.rotation.y = 0;
    const scaledBox = new THREE.Box3().setFromObject(group);
    group.position.y = -scaledBox.min.y;
    return group;
  } catch (e) {
    return null;
  }
}
async function loadModelFromUrl(
  modelUrl,
  position,
  scale = 1.0,
  name = 'model'
) {
  try {
    const cachedModel = await modelCache.loadModel(modelUrl, true);
    const modelInstance = cachedModel.clone(true);
    modelInstance.traverse(child => {
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material = child.material.map(mat => mat.clone());
        } else {
          child.material = child.material.clone();
        }
      }
    });
    const box = new THREE.Box3().setFromObject(modelInstance);
    const size = box.getSize(new THREE.Vector3());
    const group = new THREE.Group();
    group.add(modelInstance);
    group.position.set(position[0], 0, position[1]);
    group.scale.set(scale, scale, scale);
    return group;
  } catch (error) {
    return null;
  }
}
async function loadEnemyModel(enemyName, position, scale = 1.0) {
  const modelUrl = getEnemyModelUrl(enemyName);
  try {
    const cachedModel = await modelCache.loadModel(modelUrl, true);
    const modelInstance = cachedModel.clone(true);
    modelInstance.traverse(child => {
      if (child.material) {
        if (Array.isArray(child.material)) {
          child.material = child.material.map(mat => mat.clone());
        } else {
          child.material = child.material.clone();
        }
      }
    });
    const box = new THREE.Box3().setFromObject(modelInstance);
    const size = box.getSize(new THREE.Vector3());
    const group = new THREE.Group();
    group.add(modelInstance);
    group.position.set(position[0], 0, position[1]);
    group.scale.set(scale, scale, scale);
    group.rotation.y = 0;
    const scaledBox = new THREE.Box3().setFromObject(group);
    group.position.y = -scaledBox.min.y;
    const pointLight = new THREE.PointLight(0xff4444, 2.5, 12);
    pointLight.position.set(0, size.y * scale * 0.8, 0);
    group.add(pointLight);
    return group;
  } catch (e) {
    return null;
  }
}
let createAttackEffectFunc = null;
function setupMessageQueue() {
  const stateIndicators = new Map();
  const mapBlocks = new Map();
  const resourceMarkers = new Map();
  function createIndicator(unitId, type, show) {
    const model = models.find(m => m.id === unitId);
    if (!model || !model.object) return;
    let color, radius;
    if (type === 'move') {
      color = 0x00ff00;
      radius = 0.8;
    } else if (type === 'attack') {
      color = 0xff0000;
      radius = 1.0;
    } else if (type === 'summon') {
      color = 0xffff00;
      radius = 1.2;
    } else {
      color = 0xffffff;
      radius = 1.0;
    }
    if (!stateIndicators.has(unitId)) {
      stateIndicators.set(unitId, {});
    }
    const indicators = stateIndicators.get(unitId);
    if (indicators[type]) {
      scene.remove(indicators[type]);
      indicators[type].geometry.dispose();
      indicators[type].material.dispose();
      delete indicators[type];
    }
    if (show) {
      const geometry = new THREE.RingGeometry(radius - 0.1, radius, 32);
      const material = new THREE.MeshBasicMaterial({
        color,
        side: THREE.DoubleSide,
        transparent: true,
        opacity: 0.6,
      });
      const ring = new THREE.Mesh(geometry, material);
      ring.rotation.x = -Math.PI / 2;
      ring.position.set(model.object.position.x, 0.1, model.object.position.z);
      scene.add(ring);
      indicators[type] = ring;
    }
  }
  let selectedCopperId = null;
  const highlightSelectedCopper = copperId => {
    models.forEach(model => {
      if (model.object) {
        model.object.scale.set(1, 1, 1);
        model.object.traverse(child => {
          if (child.material) {
            child.material.emissive?.setHex(0x000000);
            if (child.material.emissiveIntensity !== undefined) {
              child.material.emissiveIntensity = 0;
            }
          }
        });
      }
    });
    if (copperId !== null) {
      const model = models.find(m => m.id === copperId);
      if (model) {
        model.object.scale.set(1.1, 1.1, 1.1);
        model.object.traverse(child => {
          if (child.material && child.material.emissive) {
            child.material.emissive.setHex(0xffaa00);
            child.material.emissiveIntensity = 0.5;
          }
        });
        selectedCopperId = copperId;
        const unitType =
          model.type === 'summon'
            ? '召唤物'
            : model.type === 'copper'
              ? '铜偶'
              : '敌人';
      }
    } else {
      selectedCopperId = null;
    }
  };
  createAttackEffectFunc = (attackerId, targetPosition) => {
    const attacker = models.find(m => m.id === attackerId);
    if (!attacker) return;
    const originalEmissives = new Map();
    attacker.object.traverse(child => {
      if (child.material && child.material.emissive) {
        originalEmissives.set(child, {
          color: child.material.emissive.getHex(),
          intensity: child.material.emissiveIntensity || 0,
        });
        child.material.emissive.setHex(0xff0000);
        child.material.emissiveIntensity = 0.8;
      }
    });
    setTimeout(() => {
      originalEmissives.forEach((original, child) => {
        if (child.material && child.material.emissive) {
          child.material.emissive.setHex(original.color);
          child.material.emissiveIntensity = original.intensity;
        }
      });
    }, 500);
    const attackerPos = new THREE.Vector3(
      attacker.object.position.x,
      0.5,
      attacker.object.position.z
    );
    const targetPos = new THREE.Vector3(
      targetPosition[0],
      0.5,
      targetPosition[1]
    );
    const direction = new THREE.Vector3().subVectors(targetPos, attackerPos);
    const distance = direction.length();
    const midpoint = new THREE.Vector3()
      .addVectors(attackerPos, targetPos)
      .multiplyScalar(0.5);
    const cylinderGeometry = new THREE.CylinderGeometry(
      0.05,
      0.05,
      distance,
      8
    );
    const cylinderMaterial = new THREE.MeshBasicMaterial({
      color: 0xff4444,
      transparent: true,
      opacity: 0.9,
      emissive: 0xff4444,
      emissiveIntensity: 0.5,
    });
    const line = new THREE.Mesh(cylinderGeometry, cylinderMaterial);
    line.position.copy(midpoint);
    line.quaternion.setFromUnitVectors(
      new THREE.Vector3(0, 1, 0),
      direction.normalize()
    );
    scene.add(line);
    const ringGeometry = new THREE.RingGeometry(0.2, 0.4, 32);
    const ringMaterial = new THREE.MeshBasicMaterial({
      color: 0xff0000,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: 0.8,
      emissive: 0xff0000,
      emissiveIntensity: 0.5,
    });
    const ring = new THREE.Mesh(ringGeometry, ringMaterial);
    ring.rotation.x = -Math.PI / 2;
    ring.position.copy(targetPos);
    scene.add(ring);
    const startTime = performance.now();
    const duration = 300;
    function animateEffect() {
      const elapsed = performance.now() - startTime;
      const progress = elapsed / duration;
      if (progress < 1) {
        const opacity = 1 - progress;
        if (cylinderMaterial) cylinderMaterial.opacity = opacity;
        if (ringMaterial) ringMaterial.opacity = opacity;
        ring.scale.set(1 + progress * 2, 1 + progress * 2, 1);
        requestAnimationFrame(animateEffect);
      } else {
        scene.remove(line);
        scene.remove(ring);
        cylinderGeometry.dispose();
        cylinderMaterial.dispose();
        ringGeometry.dispose();
        ringMaterial.dispose();
      }
    }
    animateEffect();
  };
  messageQueue.setSceneContext({
    scene,
    camera,
    controls,
    models,
    gridCellSize: 1.0,
    focusState,
    focusOnModel: focusOnModelFunc,
    onShowCopperInfo: (copper, resources, has_attack_targets) => {
      if (
        copper.copper?.copper_type === 'CraftsMan' &&
        copper.id !== undefined
      ) {
        copperCanBuildMap.set(copper.id, copper.can_build === true);
      }
      const displayName =
        copper.copper?.copper_info?.name ||
        copper.name ||
        copper.enemy?.enemy_base?.name ||
        copper.enemy?.enemy_base?.enemy_type ||
        copper.enemy_base?.name ||
        copper.enemy_base?.enemy_type ||
        `单位 #${copper.id}`;
      if (copper.copper?.copper_type === 'CraftsMan') {
        selectedCopper.value = {
          ...copper,
          name: displayName,
          can_summon: copper.can_build === true,
        };
      } else {
        selectedCopper.value = {
          ...copper,
          name: displayName,
        };
      }
      selectedCopperResources.value = resources || [];
      hasAttackTargets.value = has_attack_targets || false;
    },
    onShowStructureInfo: (structure, resources) => {
      selectedStructure.value = structure;
      selectedStructureData.value = { structure, resources };
    },
    highlightSelectedCopper,
    createAttackEffect: createAttackEffectFunc,
    onMoveStart: (id, model) => {
      if (!props.isGameMode) return;
      if (isEnemyMoving.value && model?.type === 'enemy' && !model?.isOwned) {
        pendingEnemyMoves.value.add(id);
      }
    },
    onMoveComplete: id => {
      if (!props.isGameMode) return;
      const model = models.find(m => m.id === id);
      if (model?.type === 'structure') {
        currentActionMode.value = null;
        isMoveLocked.value = false;
        setTimeout(async () => {
          await handleClickStructure(id);
        }, 300);
        return;
      }
      const isWildEnemy = model?.type === 'enemy' && !model?.isOwned;
      if (isWildEnemy) {
        if (isEnemyMoving.value && pendingEnemyMoves.value.has(id)) {
          pendingEnemyMoves.value.delete(id);
          if (pendingEnemyMoves.value.size === 0) {
            isEnemyMoving.value = false;
          }
        } else {
        }
        return;
      }
      const isPlayerCopper = playerCoppers.value.some(
        copper => copper.id === id
      );
      const isFriendlySummon = model?.type === 'summon' || model?.isOwned;
      if (!isPlayerCopper && !isFriendlySummon) {
        return;
      }
      isMoveLocked.value = false;
      currentActionMode.value = null;
      if (copperActionPanelRef.value) {
        copperActionPanelRef.value.cancelAction();
      }
      setTimeout(async () => {
        const isSummon = model?.type === 'summon';
        if (isSummon) {
          await handleClickEnemy(id, false);
        } else {
          await handleClickCopper(id);
        }
        setTimeout(() => {
          if (
            selectedCopperResources.value &&
            selectedCopperResources.value.length > 0
          ) {
            return;
          }
          tryNextCopper();
        }, 100);
      }, 300);
    },
    onCraftResult: (success, message) => {
      alert(message);
    },
    onResourceNotEnough: message => {
      resourceDialogMessage.value = message;
      showResourceDialog.value = true;
      currentActionMode.value = null;
      currentBuildingName.value = null;
      showSummonModal.value = false;
      summonPosition.value = null;
    },
    onSummonFailed: message => {
      alert(`❌ ${message}`);
      currentActionMode.value = null;
      showSummonModal.value = false;
      summonPosition.value = null;
    },
    onShowSummonMenu: contents => {
      enemyList.value = contents || [];
    },
    onShowStructureMenu: contents => {
      if (copperActionPanelRef.value?.showBuildMenu) {
        copperActionPanelRef.value.showBuildMenu(contents || []);
      } else {
      }
    },
    onRemoveCopper: id => {
      const index = playerCoppers.value.findIndex(c => c.id === id);
      if (index > -1) {
        playerCoppers.value.splice(index, 1);
        if (selectedCopper.value && selectedCopper.value.id === id) {
          closeCopperPanel();
        }
        if (playerCoppers.value.length === 0) {
          currentCopperIndex.value = -1;
        } else if (currentCopperIndex.value === index) {
          currentCopperIndex.value = -1;
        } else if (currentCopperIndex.value > index) {
          currentCopperIndex.value -= 1;
        } else if (currentCopperIndex.value >= playerCoppers.value.length) {
          currentCopperIndex.value = playerCoppers.value.length - 1;
        }
      }
    },
    onShowResourceGain: (position, resourceChanges) => {
      if (effectsManager && Object.keys(resourceChanges).length > 0) {
        effectsManager.createResourceGainEffect(position, resourceChanges);
      }
    },
    onGameOver: () => {
      showGameOverDialog.value = true;
    },
    onGameSuccess: () => {
      showGameSuccessDialog.value = true;
    },
    onAttackComplete: id => {
      if (!props.isGameMode) return;
      const model = models.find(m => m.id === id);
      if (model?.type === 'structure') {
        currentActionMode.value = null;
        setTimeout(async () => {
          await handleClickStructure(id);
        }, 300);
        return;
      }
      const isPlayerCopper = playerCoppers.value.some(
        copper => copper.id === id
      );
      if (!isPlayerCopper) {
        return;
      }
      currentActionMode.value = null;
      if (copperActionPanelRef.value) {
        copperActionPanelRef.value.cancelAction();
      }
      setTimeout(async () => {
        const isSummon = model?.type === 'summon';
        if (isSummon) {
          await handleClickEnemy(id, false);
        } else {
          await handleClickCopper(id);
        }
        setTimeout(() => {
          if (
            selectedCopperResources.value &&
            selectedCopperResources.value.length > 0
          ) {
            return;
          }
          tryNextCopper();
        }, 100);
      }, 300);
    },
    onSetMoveBlock: position => {
      if (indicatorsManager) {
        indicatorsManager.createIndicator(position, 'move');
      }
    },
    onSetAttackBlock: position => {
      if (currentActionMode.value === 'transferring') {
        transferTargetPositions.value.push(position);
        const targetCopper = models.find(m => {
          if (m.type === 'copper' && m.object) {
            const pos = m.object.position;
            return (
              Math.abs(pos.x - position[0]) < 0.1 &&
              Math.abs(pos.z - position[1]) < 0.1
            );
          }
          return false;
        });
        if (targetCopper) {
          const copperInfo = playerCoppers.value.find(
            c => c.id === targetCopper.id
          );
          const existing = transferTargets.value.find(
            t => t.id === targetCopper.id
          );
          if (!existing) {
            transferTargets.value.push({
              id: targetCopper.id,
              name:
                targetCopper.name ||
                (copperInfo ? copperInfo.name : `铜偶 #${targetCopper.id}`) ||
                `铜偶 #${targetCopper.id}`,
              position: position,
            });
          }
        } else {
        }
      } else {
        if (indicatorsManager) {
          indicatorsManager.createIndicator(position, 'attack');
        }
        hasAttackTargets.value = true;
      }
    },
    onSetCanSummonBlock: position => {
      if (indicatorsManager) {
        indicatorsManager.createIndicator(position, 'summon');
      }
    },
    onClearBlock: position => {
      if (indicatorsManager) {
        indicatorsManager.clearIndicatorAt(position);
      }
    },
    onSetCopper: async (_id, position, copper) => {
      const existing = models.find(m => m.id === copper.id);
      if (existing) {
        return;
      }
      if (copper.copper?.copper_type === 'CraftsMan') {
        copperCanBuildMap.set(copper.id, copper.can_build === true);
      }
      if (props.isGameMode) {
        const copperData = {
          id: copper.id,
          name: copper.copper.copper_info?.name || `铜偶 #${copper.id}`,
          level: Number(copper.copper?.level ?? 0),
          turnDone: false,
        };
        if (!playerCoppers.value.find(c => c.id === copper.id)) {
          playerCoppers.value.push(copperData);
        }
      }
      const copperType = copper.copper.copper_type || 'Arcanist';
      const copperChineseName = copper.copper.copper_info?.name || 'default';
      const modelUrl = copper.copper.copper_info?.model_url;
      let modelScale = 1.0;
      switch (copperType) {
        case 'IronWall':
          modelScale = 1.2;
          break;
        case 'Arcanist':
          modelScale = 1.0;
          break;
        case 'Mechanic':
          modelScale = 1.1;
          break;
        case 'Resonator':
          modelScale = 1.0;
          break;
        case 'CraftsMan':
          modelScale = 1.0;
          break;
        default:
          modelScale = 1.0;
      }
      let obj;
      if (modelUrl && modelUrl.includes('/enemy/')) {
        const cdnModelUrl = getAssetUrl(modelUrl);
        obj = await loadModelFromUrl(
          cdnModelUrl,
          position,
          modelScale,
          copperChineseName
        );
        if (obj) {
          const box = new THREE.Box3().setFromObject(obj);
          const size = box.getSize(new THREE.Vector3());
          const scaledBox = new THREE.Box3().setFromObject(obj);
          obj.position.y = -scaledBox.min.y;
          const pointLight = new THREE.PointLight(0x4444ff, 2.5, 12);
          pointLight.position.set(0, size.y * modelScale * 0.8, 0);
          obj.add(pointLight);
        }
      } else {
        const copperName = getCopperEnglishName(copperChineseName);
        const typeFolder = getCopperTypeFolder(copperType);
        obj = await loadGLTFModel(typeFolder, copperName, position, modelScale);
      }
      if (!obj) {
        const geometry = new THREE.BoxGeometry(0.8, 0.8, 0.8);
        let color = 0x4488ff;
        switch (copperType) {
          case 'IronWall':
            color = 0x888888;
            break;
          case 'Arcanist':
            color = 0xff4488;
            break;
          case 'Mechanic':
            color = 0x44ff88;
            break;
          case 'Resonator':
            color = 0xffaa44;
            break;
          case 'CraftsMan':
            color = 0x4444ff;
            break;
        }
        const material = new THREE.MeshStandardMaterial({ color });
        obj = new THREE.Mesh(geometry, material);
        obj.position.set(position[0], 0.4, position[1]);
      }
      obj.userData.modelId = copper.id;
      scene.add(obj);
      const modelData = {
        id: copper.id,
        object: obj,
        name: copper.copper.copper_info?.name || `Copper_${copper.id}`,
        type: 'copper',
      };
      models.push(modelData);
    },
    onSetEnemy: async (id, position, enemy) => {
      const actualId = enemy.id;
      const isOwned = enemy.owned || false;
      const existing = models.find(m => m.id === actualId);
      if (existing) {
        return;
      }
      const enemyType = enemy.enemy_base?.enemy_type || '';
      const enemyName = enemyType.toLowerCase() || 'goblin';
      let modelScale = 1.0;
      switch (enemyName) {
        case 'demon':
        case 'glutton':
        case 'devourer':
          modelScale = 1.5;
          break;
        case 'guard':
        case 'horn':
          modelScale = 1.2;
          break;
        default:
          modelScale = 1.0;
      }
      const placeholder = {
        id: actualId,
        object: null,
        name: enemy.enemy_base?.enemy_type || `Enemy_${actualId}`,
        type: isOwned ? 'summon' : 'enemy',
        position: position,
        isOwned: isOwned,
        isLoading: true,
      };
      models.push(placeholder);
      let obj = await loadEnemyModel(enemyName, position, modelScale);
      if (!obj) {
        const geometry = new THREE.BoxGeometry(0.8, 0.8, 0.8);
        const material = new THREE.MeshStandardMaterial({
          color: isOwned ? 0x4444ff : 0xff0000,
        });
        obj = new THREE.Mesh(geometry, material);
        obj.position.set(position[0], 0.4, position[1]);
      }
      if (isOwned && obj) {
        const box = new THREE.Box3().setFromObject(obj);
        const size = box.getSize(new THREE.Vector3());
        const pointLight = new THREE.PointLight(0x4444ff, 2.5, 12);
        pointLight.position.set(0, size.y * modelScale * 0.8, 0);
        obj.add(pointLight);
      }
      obj.userData.modelId = actualId;
      scene.add(obj);
      placeholder.object = obj;
      placeholder.isLoading = false;
      if (
        enemy.now_health !== undefined &&
        enemy.enemy_base?.health !== undefined &&
        healthBarsManager
      ) {
        healthBarsManager.createOrUpdateHealthBar(
          actualId,
          enemy.now_health,
          enemy.enemy_base.health
        );
      }
      if (isOwned) {
        playerCoppers.value.push({
          id: actualId,
          name: enemy.enemy_base?.name || enemyName,
          type: 'summon',
          enemy: enemy,
        });
      }
    },
    onSetMaterial: async (id, position, material) => {
      const existing = models.find(m => m.id === id);
      if (existing) {
        return;
      }
      const materialName = material.material_base?.name || '';
      const rawModelUrl = material.material_base?.model_url;
      if (!rawModelUrl) {
        const geometry = new THREE.BoxGeometry(0.5, 0.5, 0.5);
        const placeholderMaterial = new THREE.MeshStandardMaterial({
          color: 0xffaa00,
          metalness: 0.3,
          roughness: 0.7,
        });
        const obj = new THREE.Mesh(geometry, placeholderMaterial);
        obj.position.set(position[0], 0.25, position[1]);
        obj.userData.modelId = id;
        scene.add(obj);
        models.push({
          id: id,
          object: obj,
          name: materialName || `Material_${id}`,
          type: 'material',
        });
        return;
      }
      const modelUrl = getMaterialModelUrl(rawModelUrl);
      let obj = null;
      try {
        const modelInstance = await modelCache.loadModel(modelUrl, true);
        const group = new THREE.Group();
        group.add(modelInstance);
        group.position.set(position[0], 0, position[1]);
        group.scale.set(1.0, 1.0, 1.0);
        group.rotation.y = 0;
        const scaledBox = new THREE.Box3().setFromObject(group);
        group.position.y = -scaledBox.min.y;
        obj = group;
      } catch (e) {
        const geometry = new THREE.BoxGeometry(0.5, 0.5, 0.5);
        const placeholderMaterial = new THREE.MeshStandardMaterial({
          color: 0xffaa00,
          metalness: 0.3,
          roughness: 0.7,
        });
        obj = new THREE.Mesh(geometry, placeholderMaterial);
        obj.position.set(position[0], 0.25, position[1]);
      }
      obj.userData.modelId = id;
      scene.add(obj);
      models.push({
        id: id,
        object: obj,
        name: materialName || `Material_${id}`,
        type: 'material',
      });
    },
    onSetStructure: async (id, position, structure) => {
      const existing = models.find(m => m.id === id);
      if (existing) {
        return;
      }
      const structureName = structure.structure_base?.name || '';
      const englishName = getStructureEnglishName(structureName);
      const modelUrl = getStructureModelUrl(englishName);
      let obj = null;
      try {
        const modelInstance = await modelCache.loadModel(modelUrl, true);
        const group = new THREE.Group();
        group.add(modelInstance);
        group.position.set(position[0], 0, position[1]);
        group.scale.set(1.0, 1.0, 1.0);
        group.rotation.y = 0;
        const scaledBox = new THREE.Box3().setFromObject(group);
        group.position.y = -scaledBox.min.y;
        obj = group;
      } catch (e) {
        const geometry = new THREE.BoxGeometry(0.9, 1.2, 0.9);
        const material = new THREE.MeshStandardMaterial({
          color: 0x666666,
          metalness: 0.5,
          roughness: 0.6,
        });
        obj = new THREE.Mesh(geometry, material);
        obj.position.set(position[0], 0.6, position[1]);
      }
      obj.userData.modelId = id;
      scene.add(obj);
      models.push({
        id: id,
        object: obj,
        name: structureName || `Structure_${id}`,
        type: 'structure',
      });
      if (
        structure.now_health !== undefined &&
        structure.structure_base?.health &&
        healthBarsManager
      ) {
        healthBarsManager.createOrUpdateHealthBar(
          id,
          structure.now_health,
          structure.structure_base.health
        );
      }
    },
    onPutResourceMarker: position => {
      const key = `${position[0]},${position[1]}`;
      if (resourceMarkers.has(key)) {
        const oldMarker = resourceMarkers.get(key);
        scene.remove(oldMarker);
        oldMarker.traverse(obj => {
          if (obj.geometry) obj.geometry.dispose();
          if (obj.material) {
            if (Array.isArray(obj.material)) {
              obj.material.forEach(m => m.dispose());
            } else {
              obj.material.dispose();
            }
          }
        });
        resourceMarkers.delete(key);
      }
      const group = new THREE.Group();
      const bodyGeometry = new THREE.CylinderGeometry(0.15, 0.2, 0.25, 8);
      const bodyMaterial = new THREE.MeshStandardMaterial({
        color: 0xffd700,
        emissive: 0xffaa00,
        emissiveIntensity: 0.6,
        metalness: 0.7,
        roughness: 0.3,
      });
      const body = new THREE.Mesh(bodyGeometry, bodyMaterial);
      body.position.y = 0.125;
      group.add(body);
      const topGeometry = new THREE.SphereGeometry(0.08, 8, 8);
      const topMaterial = new THREE.MeshStandardMaterial({
        color: 0xffff00,
        emissive: 0xffff00,
        emissiveIntensity: 1.0,
      });
      const top = new THREE.Mesh(topGeometry, topMaterial);
      top.position.y = 0.3;
      group.add(top);
      const worldX = position[0];
      const worldZ = position[1];
      group.position.set(worldX, 0.15, worldZ);
      const pointLight = new THREE.PointLight(0xffd700, 1.5, 3);
      pointLight.position.set(0, 0.3, 0);
      group.add(pointLight);
      scene.add(group);
      resourceMarkers.set(key, group);
    },
    onClearResourceMarker: position => {
      const key = `${position[0]},${position[1]}`;
      if (resourceMarkers.has(key)) {
        const marker = resourceMarkers.get(key);
        scene.remove(marker);
        marker.traverse(obj => {
          if (obj.geometry) obj.geometry.dispose();
          if (obj.material) {
            if (Array.isArray(obj.material)) {
              obj.material.forEach(m => m.dispose());
            } else {
              obj.material.dispose();
            }
          }
        });
        resourceMarkers.delete(key);
      }
    },
    onDisplayCanMove: (unitId, canMove) => {
      createIndicator(unitId, 'move', canMove);
      if (selectedCopper.value && selectedCopper.value.id === unitId) {
        selectedCopper.value = {
          ...selectedCopper.value,
          can_move: canMove,
        };
      }
    },
    onDisplayCanAttack: (unitId, canAttack) => {
      createIndicator(unitId, 'attack', canAttack);
      if (selectedCopper.value && selectedCopper.value.id === unitId) {
        selectedCopper.value = {
          ...selectedCopper.value,
          can_attack: canAttack,
        };
      }
    },
    onDisplayCanSummon: (unitId, canSummon) => {
      let actualCanSummon = canSummon;
      let isCreaftsman = false;
      let canBuild = false;
      if (selectedCopper.value && selectedCopper.value.id === unitId) {
        isCreaftsman = selectedCopper.value.copper?.copper_type === 'CraftsMan';
        canBuild = selectedCopper.value.can_build === true;
      } else if (copperCanBuildMap.has(unitId)) {
        isCreaftsman = true;
        canBuild = copperCanBuildMap.get(unitId);
      }
      if (isCreaftsman) {
        actualCanSummon = canBuild;
      }
      createIndicator(unitId, 'summon', actualCanSummon);
      if (selectedCopper.value && selectedCopper.value.id === unitId) {
        selectedCopper.value = {
          ...selectedCopper.value,
          can_summon: actualCanSummon,
        };
      }
    },
    onClearState: unitId => {
      if (stateIndicators.has(unitId)) {
        const indicators = stateIndicators.get(unitId);
        if (indicators.move) {
          scene.remove(indicators.move);
          indicators.move.geometry.dispose();
          indicators.move.material.dispose();
          delete indicators.move;
        }
        if (indicators.attack) {
          scene.remove(indicators.attack);
          indicators.attack.geometry.dispose();
          indicators.attack.material.dispose();
          delete indicators.attack;
        }
        if (indicators.summon) {
          scene.remove(indicators.summon);
          indicators.summon.geometry.dispose();
          indicators.summon.material.dispose();
          delete indicators.summon;
        }
        stateIndicators.delete(unitId);
      }
    },
    onUpdateHealth: (unitId, nowHealth, maxHealth) => {
      const prevHealth = previousHealth.get(unitId);
      if (prevHealth !== undefined && nowHealth < prevHealth && nowHealth > 0) {
        const model = models.find(m => m.id === unitId);
        if (model) {
          const isCopper = model.type === 'copper';
          const soundRef = isCopper
            ? meHurtSoundRef.value
            : enemyHurtSoundRef.value;
          if (soundRef) {
            soundRef.currentTime = 0;
            soundRef.play().catch(err => {
            });
          }
        }
      }
      previousHealth.set(unitId, nowHealth);
      if (healthBarsManager) {
        healthBarsManager.createOrUpdateHealthBar(unitId, nowHealth, maxHealth);
      }
    },
    onRemoveHealthBar: unitId => {
      if (healthBarsManager) {
        healthBarsManager.removeHealthBar(unitId);
      }
      previousHealth.delete(unitId);
    },
    onPutMapBlock: position => {
      const key = `${position[0]},${position[1]}`;
      if (mapBlocks.has(key)) {
        const block = mapBlocks.get(key);
        scene.remove(block);
        block.geometry.dispose();
        if (block.material) {
          if (block.material.map) block.material.map.dispose();
          if (Array.isArray(block.material)) {
            block.material.forEach(mat => {
              if (mat.map) mat.map.dispose();
              mat.dispose();
            });
          } else {
            block.material.dispose();
          }
        }
      }
      const cellConfig = getGridCellMaterialConfig();
      if (!cellConfig.enabled) {
        return;
      }
      const size = cellConfig.size || 0.9;
      const height = 0.05;
      const geometry = new THREE.BoxGeometry(size, height, size);
      let material;
      if (cellConfig.materialType === 'texture' && cellConfig.texture.url) {
        const textureLoader = new THREE.TextureLoader();
        const texture = textureLoader.load(cellConfig.texture.url);
        texture.colorSpace = THREE.SRGBColorSpace;
        texture.wrapS = THREE.RepeatWrapping;
        texture.wrapT = THREE.RepeatWrapping;
        texture.repeat.set(
          cellConfig.texture.repeat.x,
          cellConfig.texture.repeat.y
        );
        const opacity = 1.0;
        material = new THREE.MeshStandardMaterial({
          map: texture,
          transparent: false,
          opacity: opacity,
          depthTest: true,
          depthWrite: true,
        });
      } else if (cellConfig.materialType === 'standard') {
        const opacity = 1.0;
        material = new THREE.MeshStandardMaterial({
          color: cellConfig.standard.color,
          roughness: cellConfig.standard.roughness,
          metalness: cellConfig.standard.metalness,
          transparent: false,
          opacity: opacity,
          depthTest: true,
          depthWrite: true,
        });
      } else {
        const opacity = 1.0;
        material = new THREE.MeshBasicMaterial({
          color: cellConfig.basic.color,
          transparent: false,
          opacity: opacity,
          depthTest: true,
          depthWrite: true,
        });
      }
      const block = new THREE.Mesh(geometry, material);
      block.renderOrder = -100;
      const yOffset = cellConfig.yOffset || 0;
      block.position.set(position[0], height / 2 + yOffset, position[1]);
      scene.add(block);
      mapBlocks.set(key, block);
    },
    animateModelMove: (model, targetPosition, onComplete) => {
      if (!model || !model.object) return;
      const isEnemy = model.type === 'enemy';
      const soundRef = isEnemy ? moveEnemySoundRef.value : moveSoundRef.value;
      if (soundRef) {
        soundRef.currentTime = 0;
        soundRef.play().catch(err => {
        });
      }
      model.isMoving = true;
      const startPosition = model.object.position.clone();
      const target = new THREE.Vector3(
        targetPosition.x,
        targetPosition.y,
        targetPosition.z
      );
      const duration = 500;
      const startTime = performance.now();
      function animate() {
        if (!model || !model.object) {
          if (onComplete) onComplete();
          return;
        }
        const elapsed = performance.now() - startTime;
        const progress = Math.min(elapsed / duration, 1);
        const easeProgress = 1 - Math.pow(1 - progress, 2);
        model.object.position.lerpVectors(startPosition, target, easeProgress);
        if (progress < 1) {
          requestAnimationFrame(animate);
        } else {
          model.object.position.copy(target);
          model.isMoving = false;
          if (onComplete) onComplete();
        }
      }
      animate();
    },
    setTestMode: mode => {
      models.forEach(model => {
        if (model.type === 'test') {
          model.object.visible = mode === 'backend';
        } else if (model.type === 'copper' || model.type === 'enemy') {
          model.object.visible = mode === 'eventloop';
        }
      });
    },
  });
}
function focusOnModelFunc(modelObject, camera, controls) {
  const worldOrigin = new THREE.Vector3();
  modelObject.getWorldPosition(worldOrigin);
  const distance = window.cameraFocusDistance || 8;
  const height = window.cameraFocusHeight || 6;
  const offsetX = 0;
  const offsetZ = distance;
  const targetPosition = new THREE.Vector3(
    worldOrigin.x + offsetX,
    worldOrigin.y + height,
    worldOrigin.z + offsetZ
  );
  return {
    focusPosition: targetPosition.clone(),
    focusTarget: worldOrigin.clone(),
    lerpFactor: 0.1,
  };
}
function onWindowResize() {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
}
function animate() {
  requestAnimationFrame(animate);
  if (keys.w || keys.a || keys.s || keys.d || keys.shift || keys.space) {
    const velocity = new THREE.Vector3();
    if (keys.w) velocity.z -= 1;
    if (keys.s) velocity.z += 1;
    if (keys.a) velocity.x -= 1;
    if (keys.d) velocity.x += 1;
    if (keys.shift) velocity.y -= 1;
    if (keys.space) velocity.y += 1;
    velocity.applyQuaternion(camera.quaternion);
    velocity.y = keys.shift ? -1 : keys.space ? 1 : 0;
    camera.position.add(velocity.multiplyScalar(moveSpeed));
  }
  if (focusState.focusPosition && focusState.focusTarget) {
    camera.position.lerp(focusState.focusPosition, focusState.lerpFactor);
    camera.lookAt(focusState.focusTarget);
    yaw = camera.rotation.y;
    pitch = camera.rotation.x;
    const distance = camera.position.distanceTo(focusState.focusPosition);
    if (distance < 0.5) {
      focusState.focusPosition = null;
      focusState.focusTarget = null;
    }
  }
  if (healthBarsManager) {
    healthBarsManager.updateHealthBarsPosition(models);
  }
  renderer.render(scene, camera);
}
function goBack() {
  emit('back');
}
function onSceneClick(event) {
  if (event.target.tagName !== 'CANVAS') return;
  mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
  mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
  raycaster.setFromCamera(mouse, camera);
  if (
    currentActionMode.value === 'moving' ||
    currentActionMode.value === 'attacking' ||
    currentActionMode.value === 'summoning' ||
    currentActionMode.value === 'building' ||
    currentActionMode.value === 'transferring' ||
    currentActionMode.value === 'structureMoving' ||
    currentActionMode.value === 'structureAttacking' ||
    currentActionMode.value === 'structureExtract' ||
    currentActionMode.value === 'structureTransfer'
  ) {
    handleFloorClick(mouse);
    return;
  }
  const clickableObjects = models
    .filter(
      m =>
        (m.type === 'copper' ||
          m.type === 'summon' ||
          m.type === 'enemy' ||
          m.type === 'structure') &&
        m.object
    )
    .map(m => m.object);
  const intersects = raycaster.intersectObjects(clickableObjects, true);
  if (intersects.length > 0) {
    let clickedObject = intersects[0].object;
    while (clickedObject.parent && !clickedObject.userData.modelId) {
      clickedObject = clickedObject.parent;
    }
    const modelId = clickedObject.userData.modelId;
    if (modelId !== undefined) {
      const model = models.find(m => m.id === modelId);
      const unitTypeMap = {
        copper: '铜偶',
        summon: '友方召唤物',
        enemy: '野生敌人',
        structure: '建筑',
      };
      const unitType = unitTypeMap[model?.type] || '未知单位';
      if (model?.type === 'summon' || model?.type === 'enemy') {
        handleClickEnemy(modelId, model?.type === 'enemy');
      } else if (model?.type === 'structure') {
        handleClickStructure(modelId);
      } else {
        handleClickCopper(modelId);
      }
    }
  } else {
    selectedCopper.value = null;
    selectedStructure.value = null;
  }
}
async function handleFloorClick(mousePos) {
  const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(mousePos, camera);
  if (currentActionMode.value === 'moving' && isMoveLocked.value) {
    return;
  }
  const intersectPoint = new THREE.Vector3();
  raycaster.ray.intersectPlane(plane, intersectPoint);
  if (intersectPoint) {
    const gridX = Math.round(intersectPoint.x);
    const gridZ = Math.round(intersectPoint.z);
    const expectedType = {
      moving: 'move',
      attacking: 'attack',
      summoning: 'summon',
      building: 'summon',
      structureMoving: 'move',
      structureAttacking: 'attack',
      structureExtract: 'attack',
      structureTransfer: 'attack',
    }[currentActionMode.value];
    if (
      !indicatorsManager ||
      !indicatorsManager.hasIndicatorAt([gridX, gridZ], expectedType)
    ) {
      return;
    }
    if (currentActionMode.value === 'moving') {
      await handleMoveApply(gridX, gridZ);
    } else if (currentActionMode.value === 'attacking') {
      await handleAttackApply(gridX, gridZ);
    } else if (currentActionMode.value === 'summoning') {
      await handleSummonApply(gridX, gridZ);
    } else if (currentActionMode.value === 'building') {
      await handleBuildApply(gridX, gridZ);
    } else if (currentActionMode.value === 'structureMoving') {
      await handleStructureMoveApply(gridX, gridZ);
    } else if (currentActionMode.value === 'structureAttacking') {
      await handleStructureAttackApply(gridX, gridZ);
    } else if (currentActionMode.value === 'structureExtract') {
      await handleStructureExtractApply(gridX, gridZ);
    } else if (currentActionMode.value === 'structureTransfer') {
      await handleStructureTransferApply(gridX, gridZ);
    }
  }
}
async function handleMoveApply(x, z) {
  if (!selectedCopper.value) return;
  if (isMoveLocked.value) {
    return;
  }
  const isOwnedEnemy = selectedCopper.value.isOwnedEnemy === true;
  const eventType = isOwnedEnemy ? 'on_enemy_move_apply' : 'on_move_apply';
  const message = JSON.stringify({
    type: eventType,
    content: {
      id: String(selectedCopper.value.id),
      position: { x: String(x), y: String(z) },
    },
  });
  isMoveLocked.value = true;
  await eventloop(message);
}
async function handleAttackApply(x, z) {
  if (!selectedCopper.value) return;
  const isOwnedEnemy = selectedCopper.value.isOwnedEnemy === true;
  const eventType = isOwnedEnemy ? 'on_enemy_attack_apply' : 'on_attack_apply';
  const attackerId = selectedCopper.value.id;
  const attacker = models.find(m => m.id === attackerId);
  if (attacker) {
    const isEnemy = attacker.type === 'enemy';
    const soundRef = isEnemy ? attackEnemySoundRef.value : attackSoundRef.value;
    if (soundRef) {
      soundRef.currentTime = 0;
      soundRef.play().catch(err => {
      });
    }
    if (createAttackEffectFunc) {
      createAttackEffectFunc(attackerId, [x, z]);
    }
  }
  const message = JSON.stringify({
    type: eventType,
    content: {
      id: String(selectedCopper.value.id),
      position: { x: String(x), y: String(z) },
    },
  });
  await eventloop(message);
}
async function handleSummonApply(x, z) {
  if (!selectedCopper.value) return;
  summonPosition.value = [x, z];
  const message = JSON.stringify({
    type: 'on_get_summon_menu',
  });
  await eventloop(message);
  await new Promise(resolve => setTimeout(resolve, 100));
  showSummonModal.value = true;
}
async function handleBuildApply(x, z) {
  if (!selectedCopper.value || !currentBuildingName.value) return;
  const copperId = selectedCopper.value.id;
  const message = JSON.stringify({
    type: 'on_structure_build_apply',
    content: {
      id: String(copperId),
      position: { x: String(x), y: String(z) },
      name: currentBuildingName.value,
    },
  });
  await eventloop(message);
  currentActionMode.value = null;
  currentBuildingName.value = null;
  if (copperActionPanelRef.value) {
    copperActionPanelRef.value.cancelAction();
  }
  await new Promise(resolve => setTimeout(resolve, 100));
  await handleClickCopper(copperId);
}
async function handleSummonConfirm(enemyName) {
  if (!selectedCopper.value || !summonPosition.value) return;
  const [x, z] = summonPosition.value;
  try {
    const message = JSON.stringify({
      type: 'on_summon_apply',
      content: {
        id: String(selectedCopper.value.id),
        position: { x: String(x), y: String(z) },
        name: enemyName,
      },
    });
    await eventloop(message);
  } catch (error) {
  } finally {
    showSummonModal.value = false;
    currentActionMode.value = null;
    summonPosition.value = null;
    if (copperActionPanelRef.value) {
      copperActionPanelRef.value.cancelAction();
    }
    try {
      const endMessage = JSON.stringify({ type: 'on_summon_end' });
      await eventloop(endMessage);
    } catch (error) {
    }
  }
}
function handleCloseSummonModal() {
  showSummonModal.value = false;
  summonPosition.value = null;
  currentActionMode.value = null;
  const endMessage = JSON.stringify({ type: 'on_summon_end' });
  eventloop(endMessage).catch(e => {
  });
}
function handleStructurePanelCancel() {
  if (currentActionMode.value === 'structureMoving') {
    const message = JSON.stringify({ type: 'on_structure_move_end' });
    eventloop(message).catch(e => {
    });
  } else if (currentActionMode.value === 'structureAttacking') {
    const message = JSON.stringify({ type: 'on_structure_attack_end' });
    eventloop(message).catch(e => {
    });
  } else if (currentActionMode.value === 'structureExtract') {
    const message = JSON.stringify({ type: 'on_structure_extract_end' });
    eventloop(message).catch(e => {
    });
  } else if (currentActionMode.value === 'structureTransfer') {
    const message = JSON.stringify({ type: 'on_structure_transfer_end' });
    eventloop(message).catch(e => {
    });
  }
  currentActionMode.value = null;
}
function closeStructurePanel() {
  handleStructurePanelCancel();
  selectedStructure.value = null;
  selectedStructureData.value = null;
}
async function handleStructureAction(action) {
  if (!selectedStructure.value) return;
  const structureId = selectedStructure.value.id;
  switch (action.type) {
    case 'move':
      await handleStructureMoveStart(structureId);
      break;
    case 'attack':
      await handleStructureAttackStart(structureId);
      break;
    case 'transfer':
      await handleStructureTransferStart(structureId);
      break;
    case 'extract':
      await handleStructureExtractStart(structureId);
      break;
    default:
  }
}
async function handleStructureMoveStart(structureId) {
  const message = JSON.stringify({
    type: 'on_structure_move_start',
    content: { id: String(structureId) },
  });
  await eventloop(message);
  currentActionMode.value = 'structureMoving';
}
async function handleStructureAttackStart(structureId) {
  const message = JSON.stringify({
    type: 'on_structure_attack_start',
    content: { id: String(structureId) },
  });
  await eventloop(message);
  currentActionMode.value = 'structureAttacking';
}
async function handleStructureExtractStart(structureId) {
  const message = JSON.stringify({
    type: 'on_structure_extract_start',
    content: { id: String(structureId) },
  });
  await eventloop(message);
  currentActionMode.value = 'structureExtract';
}
async function handleStructureTransferStart(structureId) {
  const message = JSON.stringify({
    type: 'on_structure_transfer_start',
    content: { id: String(structureId) },
  });
  await eventloop(message);
  currentActionMode.value = 'structureTransfer';
}
async function handleStructureMoveApply(x, z) {
  if (!selectedStructure.value) return;
  const message = JSON.stringify({
    type: 'on_structure_move_apply',
    content: {
      id: String(selectedStructure.value.id),
      position: { x: String(x), y: String(z) },
    },
  });
  await eventloop(message);
  currentActionMode.value = null;
}
async function handleStructureAttackApply(x, z) {
  if (!selectedStructure.value) return;
  const message = JSON.stringify({
    type: 'on_structure_attack_apply',
    content: {
      id: String(selectedStructure.value.id),
      position: { x: String(x), y: String(z) },
    },
  });
  await eventloop(message);
  currentActionMode.value = null;
}
async function handleStructureExtractApply(x, z) {
  if (!selectedStructure.value) return;
  const structureId = selectedStructure.value.id;
  const message = JSON.stringify({
    type: 'on_structure_extract_apply',
    content: {
      id: String(structureId),
      position: { x: String(x), y: String(z) },
    },
  });
  await eventloop(message);
  const endMessage = JSON.stringify({ type: 'on_structure_extract_end' });
  await eventloop(endMessage);
  await new Promise(resolve => setTimeout(resolve, 100));
  currentActionMode.value = null;
  setTimeout(async () => {
    await handleClickStructure(structureId);
  }, 300);
}
async function handleStructureTransferApply(x, z) {
  if (!selectedStructure.value) return;
  const structureId = selectedStructure.value.id;
  const message = JSON.stringify({
    type: 'on_structure_transfer_apply',
    content: {
      id: String(structureId),
      position: { x: String(x), y: String(z) },
    },
  });
  await eventloop(message);
  const endMessage = JSON.stringify({ type: 'on_structure_transfer_end' });
  await eventloop(endMessage);
  await new Promise(resolve => setTimeout(resolve, 100));
  currentActionMode.value = null;
  setTimeout(async () => {
    await handleClickStructure(structureId);
  }, 300);
}
async function handleClickCopper(copperId) {
  const index = playerCoppers.value.findIndex(c => c.id === copperId);
  if (index !== -1) {
    currentCopperIndex.value = index;
  }
  selectedStructure.value = null;
  const message = JSON.stringify({
    type: 'on_click_copper',
    content: { id: String(copperId) },
  });
  await eventloop(message);
}
async function handleClickStructure(structureId) {
  selectedCopper.value = null;
  const message = JSON.stringify({
    type: 'on_click_structure',
    content: { id: String(structureId) },
  });
  await eventloop(message);
}
async function handleClickEnemy(enemyId, isWildEnemy = false) {
  if (!isWildEnemy) {
    const index = playerCoppers.value.findIndex(c => c.id === enemyId);
    if (index !== -1) {
      currentCopperIndex.value = index;
    }
  } else {
    currentCopperIndex.value = -1;
    closeCopperPanel();
  }
  selectedStructure.value = null;
  const message = JSON.stringify({
    type: 'on_click_enemy',
    content: { id: String(enemyId) },
  });
  await eventloop(message);
}
function closeCopperPanel() {
  selectedCopper.value = null;
  selectedCopperResources.value = [];
  currentActionMode.value = null;
}
async function handleCopperAction(action) {
  if (action.type === 'moveStart') {
    currentActionMode.value = 'moving';
  } else if (action.type === 'attackStart') {
    currentActionMode.value = 'attacking';
  } else if (action.type === 'summonStart') {
    currentActionMode.value = 'summoning';
  } else if (action.type === 'buildRequest') {
    const message = JSON.stringify({
      type: 'on_get_structure_menu',
    });
    await eventloop(message);
  } else if (action.type === 'buildStart') {
    currentActionMode.value = 'building';
    currentBuildingName.value = action.structureName || null;
  } else if (
    action.type === 'transferring' ||
    action.type === 'transferStart'
  ) {
    currentActionMode.value = 'transferring';
    transferTargetPositions.value = [];
    transferTargets.value = [];
  } else if (action.type === 'transferComplete') {
    currentActionMode.value = null;
    transferTargetPositions.value = [];
    transferTargets.value = [];
  } else if (action.type === 'cancel') {
    const mode = currentActionMode.value;
    if (mode === 'moving') {
      const message = JSON.stringify({ type: 'on_move_end' });
      eventloop(message).catch(e => {
      });
    } else if (mode === 'attacking') {
      const message = JSON.stringify({ type: 'on_attack_end' });
      eventloop(message).catch(e => {
      });
    } else if (mode === 'transferring') {
      const message = JSON.stringify({ type: 'on_transfer_end' });
      eventloop(message).catch(e => {
      });
      transferTargetPositions.value = [];
      transferTargets.value = [];
    } else if (mode === 'summoning') {
      const message = JSON.stringify({ type: 'on_summon_end' });
      eventloop(message).catch(e => {
      });
      showSummonModal.value = false;
    } else if (mode === 'building') {
      const message = JSON.stringify({ type: 'on_structure_build_end' });
      eventloop(message).catch(e => {
      });
      currentBuildingName.value = null;
      summonPosition.value = null;
    }
    currentActionMode.value = null;
  } else if (action.type === 'wait') {
    nextCopper();
  }
}
function tryNextCopper() {
  if (playerCoppers.value.length === 0) return;
  if (selectedCopper.value) {
    const canMove = selectedCopper.value.can_move;
    const canAttack = selectedCopper.value.can_attack;
    const canSummon = selectedCopper.value.can_summon;
    const hasValidActions =
      canMove || (canAttack && hasAttackTargets.value) || canSummon;
    if (hasValidActions) {
      return;
    }
  }
  nextCopper();
}
async function nextCopper() {
  if (playerCoppers.value.length === 0) return;
  selectedCopper.value = null;
  currentActionMode.value = null;
  const startIndex = currentCopperIndex.value;
  let attempts = 0;
  const maxAttempts = playerCoppers.value.length;
  while (attempts < maxAttempts) {
    currentCopperIndex.value =
      (currentCopperIndex.value + 1) % playerCoppers.value.length;
    const nextCopper = playerCoppers.value[currentCopperIndex.value];
    await new Promise(resolve => {
      setTimeout(async () => {
        const model = models.find(m => m.id === nextCopper.id);
        const isSummon = model?.type === 'summon';
        if (isSummon) {
          await handleClickEnemy(nextCopper.id, false);
        } else {
          await handleClickCopper(nextCopper.id);
        }
        resolve();
      }, 300);
    });
    await new Promise(resolve => setTimeout(resolve, 200));
    const canMove = selectedCopper.value?.can_move || false;
    const canAttack = selectedCopper.value?.can_attack || false;
    const canSummon = selectedCopper.value?.can_summon || false;
    const hasValidActions =
      canMove || (canAttack && hasAttackTargets.value) || canSummon;
    if (selectedCopper.value && hasValidActions) {
      return;
    }
    attempts++;
  }
  selectedCopper.value = null;
  if (props.isGameMode) {
  }
}
function endRound() {
  currentRound.value++;
  currentCopperIndex.value = -1;
  selectedCopper.value = null;
  currentActionMode.value = null;
  playerCoppers.value.forEach(c => (c.turnDone = false));
  const wildEnemies = models.filter(m => m.type === 'enemy' && !m.isOwned);
  if (wildEnemies.length === 0) {
    isEnemyMoving.value = false;
  } else {
    isEnemyMoving.value = true;
    pendingEnemyMoves.value.clear();
    let timeoutId = setTimeout(() => {
      if (isEnemyMoving.value && pendingEnemyMoves.value.size > 0) {
        isEnemyMoving.value = false;
        pendingEnemyMoves.value.clear();
      }
    }, 3000);
    let checkInterval = setInterval(() => {
      if (!isEnemyMoving.value) {
        clearTimeout(timeoutId);
        clearInterval(checkInterval);
      }
    }, 100);
    setTimeout(() => {
      if (isEnemyMoving.value && pendingEnemyMoves.value.size === 0) {
        isEnemyMoving.value = false;
        clearTimeout(timeoutId);
        clearInterval(checkInterval);
      }
    }, 1000);
  }
}
async function handleGameOverConfirm() {
  showGameOverDialog.value = false;
  const message = JSON.stringify({ type: 'on_game_over' });
  await eventloop(message);
  emit('back');
}
async function handleGameSuccessConfirm() {
  showGameSuccessDialog.value = false;
  const message = JSON.stringify({ type: 'on_game_over' });
  await eventloop(message);
  showCreditsScreen();
}
function showCreditsScreen() {
  showCredits.value = true;
  setTimeout(() => {
    showCredits.value = false;
    emit('back');
  }, 5000);
}
function skipCredits() {
  showCredits.value = false;
  emit('back');
}
function openWithdrawDialog() {
  showWithdrawDialog.value = true;
}
function cancelWithdraw() {
  showWithdrawDialog.value = false;
}
async function confirmWithdraw() {
  showWithdrawDialog.value = false;
  const message = JSON.stringify({ type: 'on_game_over' });
  await eventloop(message);
  emit('back');
}
function closeResourceDialog() {
  showResourceDialog.value = false;
  resourceDialogMessage.value = '';
}
function resetCameraView() {
  resetCameraInternal();
}
const panel7Src = `url('${getAssetUrl('@assets/ui/panel7.png')}')`;
const panel8Src = `url('${getAssetUrl('@assets/ui/panel8.png')}')`;
</script>
<template>
  <div class="game-scene">
    <div ref="container" class="scene-container"></div>
    <TurnSystem
      v-if="isGameMode"
      :currentCopperId="currentCopperId"
      :copperList="playerCoppers"
      :roundNumber="currentRound"
      :isEnemyMoving="isEnemyMoving"
      @nextCopper="nextCopper"
      @endRound="endRound"
      @selectCopper="handleClickCopper"
    />
    <div class="top-left-actions" v-if="isGameMode">
      <button class="withdraw-button" @click="openWithdrawDialog">撤退</button>
      <button class="reset-button" @click="resetCameraView" title="重置镜头">
        重置镜头
      </button>
    </div>
    <ResourcePanel v-if="isGameMode" />
    <ActionPanel
      v-if="isGameMode && selectedCopper"
      ref="copperActionPanelRef"
      :copper="selectedCopper"
      :resources="selectedCopperResources"
      :hasAttackTargets="hasAttackTargets"
      :transferTargets="transferTargets"
      :onSelectCopper="handleClickCopper"
      @close="closeCopperPanel"
      @action="handleCopperAction"
    />
    <SummonModal
      v-if="isGameMode"
      :visible="showSummonModal"
      :copper-name="selectedCopper?.copper?.copper_info?.name || '共鸣者'"
      :enemy-list="enemyList"
      :position="summonPosition"
      @close="handleCloseSummonModal"
      @summon="handleSummonConfirm"
    />
    <StructurePanel
      v-if="isGameMode && selectedStructure"
      :structure="selectedStructure"
      :resources="selectedStructureData?.resources || []"
      :action-mode="
        currentActionMode === 'structureMoving'
          ? 'move'
          : currentActionMode === 'structureAttacking'
            ? 'attack'
            : currentActionMode === 'structureExtract'
              ? 'extract'
              : currentActionMode === 'structureTransfer'
                ? 'transfer'
                : null
      "
      @close="closeStructurePanel"
      @action="handleStructureAction"
      @cancel="handleStructurePanelCancel"
    />
    <div v-if="!isGameMode" class="info-panel">
      <h3>3D测试场景</h3>
      <p style="color: #ffd700; font-weight: 600">💡 两种测试模式：</p>
      <div
        style="
          margin: 8px 0;
          padding: 8px;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 6px;
        "
      >
        <p style="font-weight: 600">📌 后端测试（旧）</p>
        <p style="font-size: 12px">🟦 蓝色立方体 = ID:1</p>
        <p style="font-size: 12px">🟥 红色立方体 = ID:2</p>
      </div>
      <div
        style="
          margin: 8px 0;
          padding: 8px;
          background: rgba(255, 255, 255, 0.1);
          border-radius: 6px;
        "
      >
        <p style="font-weight: 600">🎮 EventLoop测试（新）</p>
        <p style="font-size: 12px">1. 点击🧪 → EventLoop</p>
        <p style="font-size: 12px">2. 点击"🎮 游戏开始"</p>
        <p style="font-size: 12px">3. 会创建3个新铜偶：</p>
        <p style="font-size: 11px">
          ⬜ 灰色=IronWall 🟪 粉红=Arcanist 🟦 蓝色=CraftsMan
        </p>
      </div>
    </div>
    <div v-if="showGameOverDialog" class="game-over-overlay">
      <div class="game-over-dialog">
        <h2 class="game-over-title">游戏结束</h2>
        <p class="game-over-message">所有铜偶已被击败</p>
        <button class="game-over-button" @click="handleGameOverConfirm">
          确定
        </button>
      </div>
    </div>
    <div v-if="showGameSuccessDialog" class="game-over-overlay">
      <div class="game-over-dialog success-dialog">
        <h2 class="success-title">🎉 胜利！ 🎉</h2>
        <p class="game-over-message">恭喜你成功完成了所有挑战！</p>
        <button
          class="game-over-button success-button"
          @click="handleGameSuccessConfirm"
        >
          确定
        </button>
      </div>
    </div>
    <div v-if="showCredits" class="credits-overlay">
      <div class="credits-container">
        <h1 class="credits-title">制作团队</h1>
        <div class="credits-content">
          <div class="credits-section">
            <h2>游戏设计</h2>
            <p>MGPIC Team</p>
          </div>
          <div class="credits-section">
            <h2>程序开发</h2>
            <p>Backend Developer</p>
            <p>Frontend Developer</p>
          </div>
          <div class="credits-section">
            <h2>美术设计</h2>
            <p>3D Artist</p>
            <p>UI Designer</p>
          </div>
          <div class="credits-section">
            <h2>音乐音效</h2>
            <p>Sound Designer</p>
          </div>
          <div class="credits-section">
            <h2>特别感谢</h2>
            <p>所有参与测试的玩家</p>
          </div>
        </div>
        <button class="skip-credits-button" @click="skipCredits">跳过</button>
      </div>
    </div>
    <div v-if="showResourceDialog" class="game-over-overlay">
      <div class="game-over-dialog">
        <h2 class="withdraw-title">资源不足</h2>
        <p class="game-over-message">{{ resourceDialogMessage }}</p>
        <div class="dialog-buttons">
          <button
            class="dialog-button confirm-button"
            @click="closeResourceDialog"
          >
            知道了
          </button>
        </div>
      </div>
    </div>
    <div v-if="showWithdrawDialog" class="game-over-overlay">
      <div class="game-over-dialog">
        <h2 class="withdraw-title">撤退确认</h2>
        <p class="game-over-message">确定要撤退吗？<br />当前进度将会丢失</p>
        <div class="dialog-buttons">
          <button class="dialog-button cancel-button" @click="cancelWithdraw">
            取消
          </button>
          <button class="dialog-button confirm-button" @click="confirmWithdraw">
            确定撤退
          </button>
        </div>
      </div>
    </div>
    <audio ref="audioRef" :src="musicUrl" loop preload="auto"></audio>
    <audio ref="moveSoundRef" :src="moveSoundUrl" preload="auto"></audio>
    <audio
      ref="moveEnemySoundRef"
      :src="moveEnemySoundUrl"
      preload="auto"
    ></audio>
    <audio ref="attackSoundRef" :src="attackSoundUrl" preload="auto"></audio>
    <audio
      ref="attackEnemySoundRef"
      :src="attackEnemySoundUrl"
      preload="auto"
    ></audio>
    <audio ref="meHurtSoundRef" :src="meHurtSoundUrl" preload="auto"></audio>
    <audio
      ref="enemyHurtSoundRef"
      :src="enemyHurtSoundUrl"
      preload="auto"
    ></audio>
  </div>
</template>
<style scoped>
.game-scene {
  position: fixed;
  inset: 0;
  background: #000;
  z-index: 9999;
}
.scene-container {
  width: 100%;
  height: 100%;
}
.info-panel {
  position: fixed;
  top: 20px;
  right: 20px;
  padding: 16px 20px;
  background: rgba(43, 26, 17, 0.9);
  color: white;
  border-radius: 12px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  z-index: 10000;
  backdrop-filter: blur(10px);
  max-width: 300px;
}
.info-panel h3 {
  margin: 0 0 12px 0;
  font-size: 18px;
  font-weight: 700;
}
.info-panel p {
  margin: 6px 0;
  font-size: 14px;
  line-height: 1.5;
}
/* 左上角操作区域：撤退 + 重置镜头 */
.top-left-actions {
  position: fixed;
  top: 20px;
  left: 20px;
  display: flex;
  gap: 12px;
  z-index: 1500;
}
.withdraw-button {
  position: static;
  background: rgba(139, 0, 0, 0.9);
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 12px;
  color: white;
  font-size: 18px;
  font-weight: 700;
  padding: 12px 24px;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  transition: all 0.2s;
  backdrop-filter: blur(10px);
}
.withdraw-button:hover {
  background: rgba(178, 34, 34, 0.95);
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(178, 34, 34, 0.5);
}
.withdraw-button:active {
  transform: translateY(0);
}
.reset-button {
  position: static;
  background: rgba(34, 85, 170, 0.9);
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-radius: 12px;
  color: white;
  font-size: 18px;
  font-weight: 700;
  padding: 12px 24px;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.4);
  transition: all 0.2s;
  backdrop-filter: blur(10px);
}
.reset-button:hover {
  background: rgba(46, 109, 199, 0.95);
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(46, 109, 199, 0.5);
}
.reset-button:active {
  transform: translateY(0);
}
/* 游戏结束对话框样式 */
.game-over-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 20000;
  animation: fadeIn 0.3s ease-out;
}
.game-over-dialog {
  box-sizing: border-box;
  border-style: solid;
  border-width: 12px;
  border-image-source: v-bind(panel7Src);
  border-image-slice: 8 fill;
  border-image-width: 12px;
  border-image-outset: 0;
  border-image-repeat: stretch;
  background-color: transparent;
  padding: 40px 60px;
  text-align: center;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  animation: scaleIn 0.3s ease-out;
}
.game-over-title {
  font-size: 48px;
  font-weight: 900;
  color: #ff4444;
  margin: 0 0 20px 0;
  text-shadow: 0 4px 8px rgba(255, 68, 68, 0.4);
}
.withdraw-title {
  font-size: 24px;
  font-weight: 900;
  letter-spacing: 2px;
  color: #ef4444;
  text-shadow: 0 2px 0 rgba(120, 0, 0, 0.35);
  margin: 0 0 20px 0;
}
.game-over-message {
  font-size: 14px;
  font-weight: 900;
  letter-spacing: 2px;
  color: #6a4931;
  margin: 0 0 40px 0;
}
.game-over-button {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
  border-radius: 12px;
  color: white;
  font-size: 20px;
  font-weight: 700;
  padding: 16px 48px;
  cursor: pointer;
  box-shadow: 0 8px 16px rgba(102, 126, 234, 0.4);
  transition: all 0.2s;
}
.game-over-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 24px rgba(102, 126, 234, 0.6);
}
.game-over-button:active {
  transform: translateY(0);
}
/* 对话框按钮组 */
.dialog-buttons {
  display: flex;
  gap: 100px;
  justify-content: center;
}
.dialog-button {
  padding: 14px 32px;
  box-sizing: border-box;
  border-style: solid;
  border-width: 12px;
  border-image-slice: 8 fill;
  border-image-width: 12px;
  border-image-outset: 0;
  border-image-repeat: stretch;
  background-color: transparent;
  color: #fff3ef;
  font-size: 14px;
  font-weight: 900;
  letter-spacing: 2px;
  cursor: pointer;
  transition: all 0.2s;
  min-width: 140px;
}
.cancel-button {
  border-image-source: v-bind(panel8Src);
}
.cancel-button:hover {
  opacity: 0.9;
}
.confirm-button {
  border-image-source: v-bind(panel7Src);
  box-shadow: 0 6px 16px rgba(245, 158, 11, 0.3);
}
.confirm-button:hover {
  opacity: 0.9;
}
.dialog-button:active {
  transform: translateY(0);
}
@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}
@keyframes scaleIn {
  from {
    transform: scale(0.8);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}
/* 游戏成功对话框样式 */
.success-dialog {
  background: linear-gradient(135deg, #1a2b11 0%, #0f1f0c 100%) !important;
  border: 3px solid rgba(100, 255, 100, 0.5) !important;
}
.success-title {
  font-size: 52px;
  font-weight: 900;
  color: #44ff44;
  margin: 0 0 20px 0;
  text-shadow:
    0 4px 8px rgba(68, 255, 68, 0.6),
    0 0 20px rgba(68, 255, 68, 0.4);
  animation: pulse 1.5s ease-in-out infinite;
}
.success-button {
  background: linear-gradient(135deg, #44ff44 0%, #22aa22 100%) !important;
  box-shadow: 0 8px 16px rgba(68, 255, 68, 0.4) !important;
}
.success-button:hover {
  box-shadow: 0 12px 24px rgba(68, 255, 68, 0.6) !important;
}
@keyframes pulse {
  0%,
  100% {
    transform: scale(1);
  }
  50% {
    transform: scale(1.05);
  }
}
/* 制作团队名单样式 */
.credits-overlay {
  position: fixed;
  inset: 0;
  background: linear-gradient(180deg, #000000 0%, #1a1a2e 50%, #000000 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 25000;
  animation: fadeIn 0.5s ease-out;
}
.credits-container {
  width: 100%;
  max-width: 800px;
  padding: 40px;
  text-align: center;
  animation: creditsScroll 5s ease-in-out;
}
.credits-title {
  font-size: 64px;
  font-weight: 900;
  color: #ffd700;
  margin: 0 0 60px 0;
  text-shadow: 0 4px 12px rgba(255, 215, 0, 0.6);
  letter-spacing: 8px;
}
.credits-content {
  display: flex;
  flex-direction: column;
  gap: 40px;
}
.credits-section {
  opacity: 0;
  animation: fadeInUp 0.8s ease-out forwards;
}
.credits-section:nth-child(1) {
  animation-delay: 0.2s;
}
.credits-section:nth-child(2) {
  animation-delay: 0.6s;
}
.credits-section:nth-child(3) {
  animation-delay: 1s;
}
.credits-section:nth-child(4) {
  animation-delay: 1.4s;
}
.credits-section:nth-child(5) {
  animation-delay: 1.8s;
}
.credits-section h2 {
  font-size: 32px;
  font-weight: 700;
  color: #88ccff;
  margin: 0 0 16px 0;
  text-shadow: 0 2px 8px rgba(136, 204, 255, 0.4);
}
.credits-section p {
  font-size: 24px;
  color: #ffffff;
  margin: 8px 0;
  opacity: 0.9;
}
.skip-credits-button {
  position: fixed;
  bottom: 40px;
  right: 40px;
  background: rgba(255, 255, 255, 0.2);
  border: 2px solid rgba(255, 255, 255, 0.4);
  border-radius: 12px;
  color: white;
  font-size: 18px;
  font-weight: 700;
  padding: 12px 32px;
  cursor: pointer;
  transition: all 0.2s;
  backdrop-filter: blur(10px);
}
.skip-credits-button:hover {
  background: rgba(255, 255, 255, 0.3);
  border-color: rgba(255, 255, 255, 0.6);
  transform: translateY(-2px);
}
@keyframes creditsScroll {
  0% {
    transform: translateY(100px);
    opacity: 0;
  }
  20% {
    transform: translateY(0);
    opacity: 1;
  }
  80% {
    transform: translateY(0);
    opacity: 1;
  }
  100% {
    transform: translateY(-50px);
    opacity: 1;
  }
}
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>