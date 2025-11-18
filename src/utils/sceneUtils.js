import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import {
  getSkyboxConfig,
  getLightingConfig,
  getCameraConfig,
  getRendererConfig,
  getDracoConfig,
  getTestUnitsConfig,
  getFloorConfig,
  getGridCellMaterialConfig,
} from './sceneConfig.js';
let skyboxMesh = null;
export function createDomeSkybox(scene, textureUrl, options = {}) {
  const { radius = 1000, segments = 32, hemisphere = false } = options;
  if (skyboxMesh) {
    scene.remove(skyboxMesh);
    if (skyboxMesh.geometry) skyboxMesh.geometry.dispose();
    if (skyboxMesh.material) {
      if (skyboxMesh.material.map) skyboxMesh.material.map.dispose();
      skyboxMesh.material.dispose();
    }
    skyboxMesh = null;
  }
  const textureLoader = new THREE.TextureLoader();
  textureLoader.load(
    textureUrl,
    texture => {
      texture.colorSpace = THREE.SRGBColorSpace;
      const geometry = hemisphere
        ? new THREE.SphereGeometry(
            radius,
            segments,
            segments,
            0,
            Math.PI * 2,
            0,
            Math.PI / 2
          )
        : new THREE.SphereGeometry(radius, segments, segments);
      const material = new THREE.MeshBasicMaterial({
        map: texture,
        side: THREE.BackSide,
        depthWrite: false,
      });
      skyboxMesh = new THREE.Mesh(geometry, material);
      skyboxMesh.position.set(0, 0, 0);
      scene.add(skyboxMesh);
    },
    undefined,
    error => {
      scene.background = new THREE.Color(0x222222);
    }
  );
}
export function loadSkybox(scene, config) {
  if (!config || !config.url) {
    scene.background = new THREE.Color(0x222222);
    return;
  }
  createDomeSkybox(scene, config.url, {
    radius: config.radius || 1000,
    segments: config.segments || 32,
    hemisphere: config.hemisphere || false,
  });
}
export function applyLighting(scene, config) {
  const ambientLight = new THREE.AmbientLight(
    config.ambient.color,
    config.ambient.intensity
  );
  scene.add(ambientLight);
  const mainDirectionalLight = new THREE.DirectionalLight(
    config.mainDirectional.color,
    config.mainDirectional.intensity
  );
  mainDirectionalLight.position.set(
    config.mainDirectional.position.x,
    config.mainDirectional.position.y,
    config.mainDirectional.position.z
  );
  mainDirectionalLight.castShadow = config.mainDirectional.castShadow;
  scene.add(mainDirectionalLight);
  const topLight = new THREE.DirectionalLight(
    config.topLight.color,
    config.topLight.intensity
  );
  topLight.position.set(
    config.topLight.position.x,
    config.topLight.position.y,
    config.topLight.position.z
  );
  scene.add(topLight);
  const hemisphereLight = new THREE.HemisphereLight(
    config.hemisphere.skyColor,
    config.hemisphere.groundColor,
    config.hemisphere.intensity
  );
  hemisphereLight.position.set(
    config.hemisphere.position.x,
    config.hemisphere.position.y,
    config.hemisphere.position.z
  );
  scene.add(hemisphereLight);
}
export function createCamera(customConfig = {}) {
  const config = { ...getCameraConfig(), ...customConfig };
  const aspect = window.innerWidth / window.innerHeight;
  const camera = new THREE.PerspectiveCamera(
    config.fov,
    aspect,
    config.near,
    config.far
  );
  camera.position.set(config.position.x, config.position.y, config.position.z);
  return camera;
}
export function createRenderer(container, customOptions = {}) {
  const config = { ...getRendererConfig(), ...customOptions };
  const width = customOptions.width || window.innerWidth;
  const height = customOptions.height || window.innerHeight;
  const renderer = new THREE.WebGLRenderer({ antialias: config.antialias });
  renderer.setSize(width, height);
  renderer.setPixelRatio(window.devicePixelRatio);
  container.appendChild(renderer.domElement);
  return renderer;
}
export function createGLTFLoader(customDracoPath = null) {
  const config = getDracoConfig();
  const dracoPath = customDracoPath || config.decoderPath;
  const gltfLoader = new GLTFLoader();
  const dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath(dracoPath);
  gltfLoader.setDRACOLoader(dracoLoader);
  return gltfLoader;
}
export function createTestUnits(scene, modelsArray) {
  const config = getTestUnitsConfig();
  if (!config.enabled) {
    return;
  }
  config.units.forEach(unitConfig => {
    const geometry = new THREE.BoxGeometry(
      unitConfig.size,
      unitConfig.size,
      unitConfig.size
    );
    const material = new THREE.MeshStandardMaterial({
      color: unitConfig.color,
    });
    const cube = new THREE.Mesh(geometry, material);
    cube.position.set(
      unitConfig.position.x,
      unitConfig.position.y,
      unitConfig.position.z
    );
    scene.add(cube);
    modelsArray.push({
      id: unitConfig.id,
      object: cube,
      name: unitConfig.name,
      type: 'test',
    });
  });
}
export function createFloor(scene, customConfig = {}) {
  const config = { ...getFloorConfig(), ...customConfig };
  if (!config.enabled) {
    return null;
  }
  const geometry = new THREE.PlaneGeometry(config.size, config.size);
  let material;
  if (config.materialType === 'texture' && config.texture.url) {
    const textureLoader = new THREE.TextureLoader();
    const texture = textureLoader.load(config.texture.url);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = THREE[config.texture.wrapS] || THREE.RepeatWrapping;
    texture.wrapT = THREE[config.texture.wrapT] || THREE.RepeatWrapping;
    texture.repeat.set(config.texture.repeat.x, config.texture.repeat.y);
    material = new THREE.MeshStandardMaterial({
      map: texture,
      side: THREE.DoubleSide,
    });
  } else if (config.materialType === 'color') {
    material = new THREE.MeshBasicMaterial({
      color: config.color.value,
      side: THREE.DoubleSide,
    });
  } else {
    const materialOptions = {
      color: config.standard.color,
      roughness: config.standard.roughness,
      metalness: config.standard.metalness,
      side: THREE.DoubleSide,
    };
    const textureLoader = new THREE.TextureLoader();
    if (config.standard.normalMap) {
      const normalMap = textureLoader.load(config.standard.normalMap);
      normalMap.colorSpace = THREE.SRGBColorSpace;
      materialOptions.normalMap = normalMap;
      materialOptions.normalScale = new THREE.Vector2(
        config.standard.normalScale.x,
        config.standard.normalScale.y
      );
    }
    if (config.standard.roughnessMap) {
      const roughnessMap = textureLoader.load(config.standard.roughnessMap);
      roughnessMap.colorSpace = THREE.SRGBColorSpace;
      materialOptions.roughnessMap = roughnessMap;
    }
    if (config.standard.aoMap) {
      const aoMap = textureLoader.load(config.standard.aoMap);
      aoMap.colorSpace = THREE.SRGBColorSpace;
      materialOptions.aoMap = aoMap;
    }
    material = new THREE.MeshStandardMaterial(materialOptions);
  }
  const floor = new THREE.Mesh(geometry, material);
  floor.position.set(config.position.x, config.position.y, config.position.z);
  floor.rotation.set(config.rotation.x, config.rotation.y, config.rotation.z);
  floor.renderOrder = -200;
  scene.add(floor);
  return floor;
}
export function createGridCells(scene, positions = [], customConfig = {}) {
  const config = { ...getGridCellMaterialConfig(), ...customConfig };
  if (!config.enabled || positions.length === 0) {
    return [];
  }
  const cells = [];
  const material = createCellMaterial(config);
  positions.forEach(([x, z]) => {
    const geometry = new THREE.PlaneGeometry(config.size, config.size);
    const cell = new THREE.Mesh(geometry, material);
    cell.rotation.x = -Math.PI / 2;
    cell.position.set(x, config.height, z);
    cell.userData = { position: [x, z], type: 'gridCell' };
    scene.add(cell);
    cells.push(cell);
  });
  return cells;
}
function createCellMaterial(config) {
  if (config.materialType === 'texture' && config.texture.url) {
    const textureLoader = new THREE.TextureLoader();
    const texture = textureLoader.load(config.texture.url);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.repeat.set(config.texture.repeat.x, config.texture.repeat.y);
    return new THREE.MeshStandardMaterial({
      map: texture,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: config.standard?.opacity || 1.0,
    });
  } else if (config.materialType === 'standard') {
    return new THREE.MeshStandardMaterial({
      color: config.standard.color,
      roughness: config.standard.roughness,
      metalness: config.standard.metalness,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: config.standard.opacity,
    });
  } else {
    return new THREE.MeshBasicMaterial({
      color: config.basic.color,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: config.basic.opacity,
    });
  }
}
export function disposeSkybox(scene) {
  if (skyboxMesh && scene) {
    scene.remove(skyboxMesh);
    if (skyboxMesh.geometry) skyboxMesh.geometry.dispose();
    if (skyboxMesh.material) {
      if (skyboxMesh.material.map) skyboxMesh.material.map.dispose();
      skyboxMesh.material.dispose();
    }
    skyboxMesh = null;
  }
}
export function initScene(container, options = {}) {
  const { createTestUnits: shouldCreateTestUnits = false, modelsArray = null } =
    options;
  const scene = new THREE.Scene();
  const skyboxCfg = getSkyboxConfig();
  loadSkybox(scene, skyboxCfg);
  const camera = createCamera();
  const renderer = createRenderer(container);
  const lightingCfg = getLightingConfig();
  applyLighting(scene, lightingCfg);
  const gltfLoader = createGLTFLoader();
  if (shouldCreateTestUnits && modelsArray) {
    createTestUnits(scene, modelsArray);
  }
  return {
    scene,
    camera,
    renderer,
    gltfLoader,
  };
}