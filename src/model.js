import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import GUI from 'lil-gui';
const modelConfigMap = new Map();
const modelUrlToNameMap = new Map();
const defaultConfig = {
  url: '',
  initialX: 0,
  initialY: 0,
  initialZ: 0,
  initialScale: 1.0,
  lightIntensity: 1.5,
  lightDistance: 100,
  lightColor: '#ffffff',
  lightPosX: 0.75,
  lightPosY: 0,
  lightPosZ: 0,
};
function setModelConfig(name, url, config) {
  modelConfigMap.set(name, { ...defaultConfig, ...config, url });
  modelUrlToNameMap.set(url, name);
}
function getModelConfig(name) {
  return modelConfigMap.get(name) || defaultConfig;
}
function getModelNameByUrl(url) {
  return modelUrlToNameMap.get(url) || 'default_model';
}
function createPointLight(modelObject, intensity = 1.5, distance = 100, color = '#ffffff', position = new THREE.Vector3(0.75, 0, 0)) {
  const pointLight = new THREE.PointLight(color, intensity, distance);
  pointLight.position.copy(position);
  modelObject.add(pointLight);
  return {
    pointLight,
    lightParams: { enabled: true, color, intensity, distance, autoIntensity: true, position: position.clone() },
  };
}
function focusOnModel(modelObject, camera, controls) {
  const worldOrigin = new THREE.Vector3(0, 0, 0);
  modelObject.localToWorld(worldOrigin);
  const size = new THREE.Box3().setFromObject(modelObject).getSize(new THREE.Vector3());
  const fov = camera.fov * (Math.PI / 180);
  const distance = Math.max((Math.max(size.x, size.y, size.z) / (2 * Math.tan(fov / 2))) * 1.5, 2);
  const dir = new THREE.Vector3();
  camera.getWorldDirection(dir);
  dir.y = 0;
  dir.normalize();
  return {
    focusPosition: worldOrigin.clone().sub(dir.multiplyScalar(distance)),
    focusTarget: worldOrigin.clone(),
    lerpFactor: 0.08,
  };
}
function createFloor(textureUrl, floorSize, gridCellSize) {
  const geometry = new THREE.PlaneGeometry(floorSize, floorSize);
  const material = textureUrl
    ? (() => {
        const texture = new THREE.TextureLoader().load(textureUrl);
        texture.colorSpace = THREE.SRGBColorSpace;
        const repeat = floorSize / gridCellSize;
        texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
        texture.repeat.set(repeat, repeat);
        return new THREE.MeshBasicMaterial({ map: texture, side: THREE.DoubleSide });
      })()
    : new THREE.MeshBasicMaterial({ color: 0x333333, side: THREE.DoubleSide });
  const floor = new THREE.Mesh(geometry, material);
  floor.rotation.x = -Math.PI / 2;
  return floor;
}
function createGridOverlay(floorSize, gridCellSize) {
  const grid = new THREE.GridHelper(
    floorSize,
    Math.floor(floorSize / gridCellSize),
    0x000000,
    0x000000
  );
  grid.position.y = 0.01;
  grid.material.opacity = 0.5;
  grid.material.transparent = true;
  return grid;
}
function createFloorHighlight(cellSize, color = 0xffff00) {
  const geometry = new THREE.PlaneGeometry(cellSize, cellSize);
  const material = new THREE.MeshBasicMaterial({
    color,
    transparent: true,
    opacity: 0.3,
    side: THREE.DoubleSide,
  });
  const highlight = new THREE.Mesh(geometry, material);
  highlight.rotation.x = -Math.PI / 2;
  highlight.visible = false;
  return highlight;
}
function loadModel(gltfLoader, scene, name, gridCellSize, modelIndex, onLoad, onError) {
  const config = getModelConfig(name);
  gltfLoader.load(config.url, gltf => {
    const obj = gltf.scene;
    const box = new THREE.Box3().setFromObject(obj);
    const center = box.getCenter(new THREE.Vector3());
    obj.position.sub(center);
    scene.add(obj);
    obj.position.add(new THREE.Vector3(config.initialX, config.initialY, config.initialZ));
    obj.scale.setScalar(config.initialScale);
    const { pointLight, lightParams } = createPointLight(
      obj,
      config.lightIntensity,
      config.lightDistance,
      config.lightColor,
      new THREE.Vector3(config.lightPosX, config.lightPosY, config.lightPosZ)
    );
    const size = box.getSize(new THREE.Vector3());
    const modelData = {
      object: obj,
      name: `Model_${modelIndex}`,
      position: obj.position,
      rotation: obj.rotation,
      scale: obj.scale,
      pointLight,
      lightParams,
      bboxInfo: { width: size.x.toFixed(6), depth: size.z.toFixed(6), height: size.y.toFixed(6) },
      outline: null,
      isMoving: false,
    };
    if (config.initialX === 0 && config.initialZ === 0) {
      const pos = obj.position;
      const ix = Math.round(pos.x / gridCellSize);
      const iz = Math.round(pos.z / gridCellSize);
      pos.set(ix * gridCellSize + gridCellSize / 2, pos.y, iz * gridCellSize + gridCellSize / 2);
    }
    onLoad?.(modelData);
  }, undefined, onError);
}
function setSelectedModel(selectedModelRef, scene, model) {
  if (selectedModelRef.current && selectedModelRef.current.outline) {
    scene.remove(selectedModelRef.current.outline);
    selectedModelRef.current.outline = null;
  }
  selectedModelRef.current = model;
  if (model) {
    const outline = createOutline(model.object);
    model.outline = outline;
    scene.add(outline);
  }
}
function createOutline(modelObject, color = 0x00ffff) {
  const box = new THREE.Box3().setFromObject(modelObject);
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const outlineGeo = new THREE.BoxGeometry(size.x, size.y, size.z);
  const outlineMaterial = new THREE.MeshBasicMaterial({
    color,
    wireframe: true,
    depthTest: false,
    transparent: true,
    opacity: 0.8,
  });
  const outline = new THREE.Mesh(outlineGeo, outlineMaterial);
  outline.position.copy(center);
  return outline;
}
function rotateModelX(modelObject, degrees, onComplete = null) {
  if (!modelObject) return;
  const targetRadians = (degrees * Math.PI) / 180;
  const startRadians = modelObject.rotation.x;
  const duration = 300;
  const startTime = performance.now();
  function animate() {
    const progress = Math.min((performance.now() - startTime) / duration, 1);
    modelObject.rotation.x = startRadians + (targetRadians - startRadians) * (1 - Math.pow(1 - progress, 2));
    if (progress < 1) {
      requestAnimationFrame(animate);
    } else {
      modelObject.rotation.x = targetRadians;
      onComplete?.();
    }
  }
  animate();
}
function setPointLightEnabled(modelData, enabled) {
  if (modelData?.pointLight) {
    modelData.pointLight.visible = enabled;
    modelData.lightParams && (modelData.lightParams.enabled = enabled);
  }
}
function animateModelMove(model, targetPosition, onComplete) {
  if (!model?.object) return;
  model.isMoving = true;
  const startPosition = model.object.position.clone();
  const duration = 500;
  const startTime = performance.now();
  function animate() {
    if (!model?.object) {
      onComplete?.();
      return;
    }
    const progress = Math.min((performance.now() - startTime) / duration, 1);
    model.object.position.lerpVectors(startPosition, targetPosition, 1 - Math.pow(1 - progress, 2));
    if (progress < 1) {
      requestAnimationFrame(animate);
    } else {
      model.object.position.copy(targetPosition);
      model.isMoving = false;
      onComplete?.();
    }
  }
  animate();
}
function getGridCellCenter(worldPoint, cellSize) {
  const ix = Math.floor(worldPoint.x / cellSize);
  const iz = Math.floor(worldPoint.z / cellSize);
  const centerX = (ix + 0.5) * cellSize;
  const centerZ = (iz + 0.5) * cellSize;
  return { x: centerX, z: centerZ, ix, iz };
}
function updateLighting(ambientLight, directionalLight, lightingParams, scene) {
  ambientLight.intensity = lightingParams.ambientIntensity;
  ambientLight.color.set(lightingParams.ambientColor);
  directionalLight.intensity = lightingParams.directionalIntensity;
  directionalLight.color.set(lightingParams.directionalColor);
  directionalLight.position.set(lightingParams.dirLightX, lightingParams.dirLightY, lightingParams.dirLightZ);
  scene.background = new THREE.Color(lightingParams.bgColor);
}
function initGUI(guiContainer, lightingParams, updateLightingCallback) {
  const gui = new GUI({ container: guiContainer });
  const lightFolder = gui.addFolder('Global Lighting');
  lightFolder.open();
  const controls = [
    { prop: 'ambientIntensity', name: 'Ambient Intensity', type: 'add', min: 0, max: 2 },
    { prop: 'ambientColor', name: 'Ambient Color', type: 'addColor' },
    { prop: 'directionalIntensity', name: 'Directional Intensity', type: 'add', min: 0, max: 5 },
    { prop: 'directionalColor', name: 'Directional Color', type: 'addColor' },
    { prop: 'dirLightX', name: 'Dir Light X', type: 'add', min: -200, max: 200 },
    { prop: 'dirLightY', name: 'Dir Light Y', type: 'add', min: -200, max: 200 },
    { prop: 'dirLightZ', name: 'Dir Light Z', type: 'add', min: -200, max: 200 },
    { prop: 'bgColor', name: 'Background Color', type: 'addColor' },
  ];
  controls.forEach(({ prop, name, type, min, max }) => {
    const ctrl = type === 'addColor' ? lightFolder.addColor(lightingParams, prop) : lightFolder.add(lightingParams, prop, min, max);
    ctrl.name(name).onChange(updateLightingCallback);
  });
  return gui;
}
function initScene(container, floorTextureUrl, floorSize, gridCellSize) {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x222222);
  const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 2000);
  camera.position.set(0, 2, 5);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  const updateSize = () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(window.devicePixelRatio);
  };
  updateSize();
  window.addEventListener('resize', updateSize);
  container.appendChild(renderer.domElement);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.8);
  const directionalLight = new THREE.DirectionalLight(0xffffff, 1);
  directionalLight.position.set(5, 10, 5);
  scene.add(ambientLight, directionalLight, createFloor(floorTextureUrl, floorSize, gridCellSize), createGridOverlay(floorSize, gridCellSize));
  const dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath('https://www.gstatic.com/draco/versioned/decoders/1.5.7/');
  const gltfLoader = new GLTFLoader();
  gltfLoader.setDRACOLoader(dracoLoader);
  return { scene, camera, renderer, controls, ambientLight, directionalLight, floor: null, gltfLoader };
}
function registerMouseMoveHandler(camera, scene, models, gridCellSize, floorHighlight, selectedModelRef) {
  const onMouseMove = (event) => {
    if (!selectedModelRef.current) {
      floorHighlight.visible = false;
      return;
    }
    const mouse = new THREE.Vector2((event.clientX / window.innerWidth) * 2 - 1, -(event.clientY / window.innerHeight) * 2 + 1);
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(mouse, camera);
    const intersection = new THREE.Vector3();
    if (raycaster.ray.intersectPlane(new THREE.Plane(new THREE.Vector3(0, 1, 0), 0), intersection)) {
      const cellCenter = getGridCellCenter(intersection, gridCellSize);
      floorHighlight.position.set(cellCenter.x, 0.005, cellCenter.z);
      floorHighlight.visible = true;
    } else {
      floorHighlight.visible = false;
    }
  };
  window.addEventListener('mousemove', onMouseMove);
  return () => window.removeEventListener('mousemove', onMouseMove);
}
function registerMouseDownHandler(
  camera,
  scene,
  models,
  gridCellSize,
  floorHighlight,
  selectedModelRef,
  setSelectedModel,
  focusState,
  cameraControls,
  holdDelay,
  guiContainer
) {
  let currentHold = null;
  let isMouseDown = false;
  function onMouseDown(event) {
    if (guiContainer && guiContainer.contains(event.target)) return;
    const mouse = new THREE.Vector2();
    mouse.x = (event.clientX / window.innerWidth) * 2 - 1;
    mouse.y = -(event.clientY / window.innerHeight) * 2 + 1;
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(mouse, camera);
    const modelMeshes = [];
    for (let i = 0; i < models.length; i++) {
      if (!models[i].isMoving) {
        models[i].object.traverse(child => {
          if (child.isMesh) modelMeshes.push(child);
        });
      }
    }
    const modelIntersects = raycaster.intersectObjects(modelMeshes, true);
    if (modelIntersects.length > 0) {
      let current = modelIntersects[0].object;
      let clickedModel = null;
      while (current) {
        for (let i = 0; i < models.length; i++) {
          if (models[i].object === current && !models[i].isMoving) {
            clickedModel = models[i];
            break;
          }
        }
        if (clickedModel) break;
        current = current.parent;
      }
      if (clickedModel) {
        if (selectedModelRef.current === clickedModel) {
          setSelectedModel(null);
          floorHighlight.visible = false;
          isMouseDown = false;
          return;
        }
        setSelectedModel(clickedModel);
        floorHighlight.visible = false;
        isMouseDown = true;
        let isHolding = true;
        const holdTimer = setTimeout(() => {
          if (isHolding && isMouseDown) {
            const focusData = focusOnModel(
              clickedModel.object,
              camera,
              cameraControls
            );
            focusState.focusPosition = focusData.focusPosition;
            focusState.focusTarget = focusData.focusTarget;
            focusState.lerpFactor = focusData.lerpFactor;
          }
        }, holdDelay);
        currentHold = {
          cancel: () => (isHolding = false),
          timer: holdTimer,
        };
        return;
      }
    }
    if (selectedModelRef.current) {
      const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
      const intersection = new THREE.Vector3();
      if (raycaster.ray.intersectPlane(plane, intersection)) {
        const cellCenter = getGridCellCenter(intersection, gridCellSize);
        const targetPosition = new THREE.Vector3(
          cellCenter.x,
          selectedModelRef.current.object.position.y,
          cellCenter.z
        );
        animateModelMove(selectedModelRef.current, targetPosition, () => {});
        setTimeout(() => {
          setSelectedModel(null);
        }, 550);
      }
    }
    if (selectedModelRef.current) {
      setSelectedModel(null);
      floorHighlight.visible = false;
    }
    isMouseDown = true;
  }
  function onMouseUp() {
    if (currentHold) {
      clearTimeout(currentHold.timer);
      currentHold.cancel();
      currentHold = null;
    }
    isMouseDown = false;
  }
  window.addEventListener('mousedown', onMouseDown);
  window.addEventListener('mouseup', onMouseUp);
  window.addEventListener('mouseleave', onMouseUp);
  return () => {
    window.removeEventListener('mousedown', onMouseDown);
    window.removeEventListener('mouseup', onMouseUp);
    window.removeEventListener('mouseleave', onMouseUp);
  };
}
function setupInteraction(
  camera,
  scene,
  models,
  floor,
  gridCellSize,
  selectedModelRef,
  setSelectedModel,
  focusState,
  cameraControls,
  holdDelay = 500,
  guiContainer = null
) {
  const floorHighlight = createFloorHighlight(gridCellSize, 0xffff00);
  scene.add(floorHighlight);
  const cleanupMouseMove = registerMouseMoveHandler(
    camera,
    scene,
    models,
    gridCellSize,
    floorHighlight,
    selectedModelRef
  );
  const cleanupMouseDown = registerMouseDownHandler(
    camera,
    scene,
    models,
    gridCellSize,
    floorHighlight,
    selectedModelRef,
    setSelectedModel,
    focusState,
    cameraControls,
    holdDelay,
    guiContainer
  );
  return {
    cleanup: () => {
      cleanupMouseMove();
      cleanupMouseDown();
      scene.remove(floorHighlight);
    },
    floorHighlight: floorHighlight,
  };
}
function animate(renderer, scene, camera, controls, moveState, focusState, onCameraUpdate) {
  const time = performance.now();
  const delta = (time - (window.lastTime || time)) / 1000;
  window.lastTime = time;
  if (focusState.focusPosition && focusState.focusTarget) {
    camera.position.lerp(focusState.focusPosition, focusState.lerpFactor);
    controls.target.lerp(focusState.focusTarget, focusState.lerpFactor);
    controls.update();
    if (camera.position.distanceTo(focusState.focusPosition) < 0.01 && controls.target.distanceTo(focusState.focusTarget) < 0.01) {
      focusState.focusPosition = focusState.focusTarget = null;
    }
  }
  if (!focusState.focusPosition) {
    const velocity = new THREE.Vector3(
      (moveState.right ? 1 : 0) - (moveState.left ? 1 : 0),
      (moveState.up ? 1 : 0) - (moveState.down ? 1 : 0),
      (moveState.back ? 1 : 0) - (moveState.forward ? 1 : 0)
    );
    if (velocity.lengthSq() > 0) {
      const direction = new THREE.Vector3();
      camera.getWorldDirection(direction);
      direction.y = 0;
      direction.normalize();
      const right = new THREE.Vector3().crossVectors(camera.up, direction).normalize();
      const move = direction.clone().multiplyScalar(velocity.z * 5.0 * delta)
        .add(right.clone().multiplyScalar(velocity.x * 5.0 * delta))
        .add(new THREE.Vector3(0, velocity.y * 5.0 * delta, 0));
      camera.position.add(move);
      controls.target.add(move);
    }
  }
  onCameraUpdate?.({ position: camera.position.clone(), rotation: new THREE.Euler().setFromQuaternion(camera.quaternion) });
  if (!focusState.focusPosition) controls.update();
  renderer.render(scene, camera);
  requestAnimationFrame(() => animate(renderer, scene, camera, controls, moveState, focusState, onCameraUpdate));
}
export {
  createPointLight,
  focusOnModel,
  createFloor,
  createGridOverlay,
  createFloorHighlight,
  loadModel,
  createOutline,
  rotateModelX,
  setPointLightEnabled,
  animateModelMove,
  getGridCellCenter,
  updateLighting,
  setupInteraction,
  animate,
  initGUI,
  initScene,
  setModelConfig,
  setSelectedModel,
};