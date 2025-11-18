import * as THREE from 'three';
import { getGridCellMaterialConfig } from '../utils/sceneConfig.js';
export function useIndicators(scene) {
  const indicators = {
    move: [],
    attack: [],
    summon: [],
  };
  const cellMaterialConfig = getGridCellMaterialConfig();
  function createCellMaterial(customConfig = {}) {
    const config = { ...cellMaterialConfig, ...customConfig };
    if (!config.enabled) {
      return new THREE.MeshBasicMaterial({
        transparent: true,
        opacity: 0,
      });
    }
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
  const indicatorConfig = {
    move: { color: 0x44ff44, opacity: 0.6 },
    attack: { color: 0xff4444, opacity: 0.6 },
    summon: { color: 0xffff00, opacity: 0.6 },
  };
  function createIndicator(position, type = 'move') {
    const [x, z] = position;
    const config = indicatorConfig[type] || indicatorConfig.move;
    const size = cellMaterialConfig.size || 0.9;
    const height = cellMaterialConfig.height || 0.08;
    const geometry = new THREE.PlaneGeometry(size, size);
    const material = new THREE.MeshBasicMaterial({
      color: config.color,
      side: THREE.DoubleSide,
      transparent: true,
      opacity: config.opacity,
    });
    const plane = new THREE.Mesh(geometry, material);
    plane.rotation.x = -Math.PI / 2;
    plane.position.set(x, height, z);
    plane.userData = { position, type };
    scene.add(plane);
    indicators[type].push(plane);
    return plane;
  }
  function clearIndicatorAt(position) {
    const [x, z] = position;
    let cleared = false;
    Object.keys(indicators).forEach(type => {
      const index = indicators[type].findIndex(plane => {
        const pos = plane.userData.position;
        return pos[0] === x && pos[1] === z;
      });
      if (index !== -1) {
        const plane = indicators[type][index];
        scene.remove(plane);
        plane.geometry.dispose();
        plane.material.dispose();
        indicators[type].splice(index, 1);
        cleared = true;
      }
    });
    return cleared;
  }
  function clearIndicators(type) {
    if (!indicators[type]) return;
    indicators[type].forEach(plane => {
      scene.remove(plane);
      plane.geometry.dispose();
      plane.material.dispose();
    });
    indicators[type] = [];
  }
  function clearAllIndicators() {
    Object.keys(indicators).forEach(type => {
      clearIndicators(type);
    });
  }
  function hasIndicatorAt(position, type) {
    const [x, z] = position;
    return indicators[type]?.some(plane => {
      const pos = plane.userData.position;
      return pos[0] === x && pos[1] === z;
    });
  }
  function dispose() {
    clearAllIndicators();
  }
  return {
    indicators,
    createIndicator,
    createCellMaterial,
    clearIndicatorAt,
    clearIndicators,
    clearAllIndicators,
    hasIndicatorAt,
    dispose,
  };
}