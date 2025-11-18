import { getAssetUrl } from './resourceLoader.js';
export const skyboxConfig = {
  url: getAssetUrl('@assets/ui/skybox.jpg'),
  radius: 1000,
  segments: 32,
  hemisphere: false,
};
export const lightingConfig = {
  ambient: { color: 0xffffff, intensity: 0.5 },
  mainDirectional: { color: 0xffffff, intensity: 1.2, position: { x: 0, y: 20, z: 5 }, castShadow: true },
  topLight: { color: 0xffffff, intensity: 0.8, position: { x: 0, y: 30, z: 0 } },
  hemisphere: { skyColor: 0xffffff, groundColor: 0x444444, intensity: 0.6, position: { x: 0, y: 20, z: 0 } },
};
export const cameraConfig = {
  fov: 60,
  near: 0.1,
  far: 2000,
  position: { x: 0, y: 5, z: 10 },
};
export const rendererConfig = { antialias: true };
export const dracoConfig = {
  decoderPath: 'https://www.gstatic.com/draco/versioned/decoders/1.5.6/',
};
export const controlConfig = {
  moveSpeed: 0.2,
  rotationSpeed: 0.003,
  focusLerpFactor: 0.08,
};
export const testUnitsConfig = {
  enabled: true,
  units: [
    { id: 1, name: '单位1', color: 0x4488ff, position: { x: 0.5, y: 0.4, z: 0.5 }, size: 0.8 },
    { id: 2, name: '单位2', color: 0xff4444, position: { x: 4.5, y: 0.4, z: 4.5 }, size: 0.8 },
  ],
};
export const gridConfig = { floorSize: 10, gridCellSize: 1 };
export const gridCellMaterialConfig = {
  enabled: true,
  materialType: 'standard',
  basic: { color: 0x4a4a4a, opacity: 0.8 },
  standard: { color: 0x5a5a6a, roughness: 0.3, metalness: 0.7, opacity: 0.8 },
  texture: { url: null, repeat: { x: 1, y: 1 } },
  size: 0.95,
  height: 0.05,
  yOffset: -0.02,
};
export const floorConfig = {
  enabled: false,
  size: 100,
  materialType: 'standard',
  texture: { url: null, repeat: { x: 10, y: 10 }, wrapS: 'RepeatWrapping', wrapT: 'RepeatWrapping' },
  color: { value: 0x2a2a2a },
  standard: { color: 0x3a3a3a, roughness: 0.8, metalness: 0.1, normalMap: null, normalScale: { x: 1, y: 1 }, roughnessMap: null, aoMap: null },
  position: { x: 0, y: 0, z: 0 },
  rotation: { x: -Math.PI / 2, y: 0, z: 0 },
};
const createGetter = (config) => () => ({ ...config });
export const getSkyboxConfig = createGetter(skyboxConfig);
export const getLightingConfig = createGetter(lightingConfig);
export const getCameraConfig = createGetter(cameraConfig);
export const getRendererConfig = createGetter(rendererConfig);
export const getDracoConfig = createGetter(dracoConfig);
export const getControlConfig = createGetter(controlConfig);
export const getTestUnitsConfig = createGetter(testUnitsConfig);
export const getGridConfig = createGetter(gridConfig);
export const getFloorConfig = createGetter(floorConfig);
export const getGridCellMaterialConfig = createGetter(gridCellMaterialConfig);
export const musicConfig = { gameScene: getAssetUrl('@assets/frontend_resource/gamescene.mp3') };
export const soundConfig = {
  move: getAssetUrl('@assets/frontend_resource/move.mp3'),
  moveEnemy: getAssetUrl('@assets/frontend_resource/move_enemy.mp3'),
  attack: getAssetUrl('@assets/frontend_resource/attack.mp3'),
  attackEnemy: getAssetUrl('@assets/frontend_resource/attack_enemy.mp3'),
  meHurt: getAssetUrl('@assets/frontend_resource/me_hurt.mp3'),
  enemyHurt: getAssetUrl('@assets/frontend_resource/enemy_hurt.mp3'),
};
export const getMusicUrl = (key) => musicConfig[key] || '';
export const getSoundUrl = (key) => soundConfig[key] || '';