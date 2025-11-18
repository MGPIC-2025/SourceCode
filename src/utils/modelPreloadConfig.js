import {
  getCopperModelUrl,
  getEnemyModelUrl,
  getStructureModelUrl,
} from './resourceLoader.js';
const COPPER_MODELS = {
  arcanist: ['bubble', 'glimmer', 'spark', 'syrup', 'turner'],
  craftsman: ['artifex', 'coil', 'drillbit', 'quickhand', 'wrench'],
  iron_wall: ['bell', 'chief', 'rocky', 'tumble', 'wesley'],
  mechanic: ['gyro', 'karin', 'pendulum', 'tricky', 'yoyo'],
  resonator: ['clawster', 'diggs', 'hive', 'melody', 'murmur'],
};
const ENEMY_MODELS = [
  'assassin',
  'boxer',
  'cruiser',
  'demon',
  'devourer',
  'glutton',
  'goblin',
  'guard',
  'horn',
  'mirror',
  'scout',
  'shatra',
  'variant',
];
const STRUCTURE_MODELS = [
  'automatic_loading_gun',
  'charging_coil',
  'heart_source_mineral_drill',
  'mirro_light_refraction_tower',
  'repair_workshop',
  'resonance_alarm_bell',
  'rivet_barrier',
  'steam_mining_car',
  'storm_anvil',
];
export function getAllModelUrls() {
  const urls = [];
  for (const [type, names] of Object.entries(COPPER_MODELS)) {
    for (const name of names) {
      const url = getCopperModelUrl(type, name);
      urls.push(url);
    }
  }
  for (const name of ENEMY_MODELS) {
    const url = getEnemyModelUrl(name);
    urls.push(url);
  }
  for (const name of STRUCTURE_MODELS) {
    const url = getStructureModelUrl(name);
    urls.push(url);
  }
  return urls;
}
export function getHighPriorityModelUrls() {
  const urls = [];
  const commonCoppers = [
    { type: 'arcanist', name: 'bubble' },
    { type: 'craftsman', name: 'coil' },
    { type: 'iron_wall', name: 'bell' },
    { type: 'mechanic', name: 'gyro' },
    { type: 'resonator', name: 'clawster' },
  ];
  for (const copper of commonCoppers) {
    const url = getCopperModelUrl(copper.type, copper.name);
    urls.push(url);
  }
  const commonEnemies = ['goblin', 'guard', 'demon'];
  for (const name of commonEnemies) {
    const url = getEnemyModelUrl(name);
    urls.push(url);
  }
  return urls;
}
export function getMediumPriorityModelUrls() {
  const urls = [];
  const mediumCoppers = [
    { type: 'arcanist', name: 'glimmer' },
    { type: 'arcanist', name: 'spark' },
    { type: 'craftsman', name: 'artifex' },
    { type: 'craftsman', name: 'wrench' },
    { type: 'iron_wall', name: 'chief' },
    { type: 'iron_wall', name: 'rocky' },
    { type: 'mechanic', name: 'karin' },
    { type: 'mechanic', name: 'tricky' },
    { type: 'resonator', name: 'diggs' },
    { type: 'resonator', name: 'hive' },
  ];
  for (const copper of mediumCoppers) {
    const url = getCopperModelUrl(copper.type, copper.name);
    urls.push(url);
  }
  const mediumEnemies = ['assassin', 'boxer', 'cruiser', 'devourer', 'glutton'];
  for (const name of mediumEnemies) {
    const url = getEnemyModelUrl(name);
    urls.push(url);
  }
  return urls;
}
export function getLowPriorityModelUrls() {
  const urls = [];
  const lowCoppers = [
    { type: 'arcanist', name: 'syrup' },
    { type: 'arcanist', name: 'turner' },
    { type: 'craftsman', name: 'drillbit' },
    { type: 'craftsman', name: 'quickhand' },
    { type: 'iron_wall', name: 'tumble' },
    { type: 'iron_wall', name: 'wesley' },
    { type: 'mechanic', name: 'pendulum' },
    { type: 'mechanic', name: 'yoyo' },
    { type: 'resonator', name: 'melody' },
    { type: 'resonator', name: 'murmur' },
  ];
  for (const copper of lowCoppers) {
    const url = getCopperModelUrl(copper.type, copper.name);
    urls.push(url);
  }
  const lowEnemies = ['horn', 'mirror', 'scout', 'shatra', 'variant'];
  for (const name of lowEnemies) {
    const url = getEnemyModelUrl(name);
    urls.push(url);
  }
  for (const name of STRUCTURE_MODELS) {
    const url = getStructureModelUrl(name);
    urls.push(url);
  }
  return urls;
}
export function getModelUrlsByPriority(priorities = ['high', 'medium']) {
  const urls = [];
  for (const priority of priorities) {
    switch (priority) {
      case 'high':
        urls.push(...getHighPriorityModelUrls());
        break;
      case 'medium':
        urls.push(...getMediumPriorityModelUrls());
        break;
      case 'low':
        urls.push(...getLowPriorityModelUrls());
        break;
    }
  }
  const uniqueUrls = [...new Set(urls)];
  return uniqueUrls;
}
export function getModelStats() {
  const stats = {
    copper: {
      arcanist: COPPER_MODELS.arcanist.length,
      craftsman: COPPER_MODELS.craftsman.length,
      iron_wall: COPPER_MODELS.iron_wall.length,
      mechanic: COPPER_MODELS.mechanic.length,
      resonator: COPPER_MODELS.resonator.length,
      total: Object.values(COPPER_MODELS).flat().length,
    },
    enemy: {
      total: ENEMY_MODELS.length,
    },
    structure: {
      total: STRUCTURE_MODELS.length,
    },
    grandTotal:
      Object.values(COPPER_MODELS).flat().length +
      ENEMY_MODELS.length +
      STRUCTURE_MODELS.length,
  };
  return stats;
}
export const MODEL_PRELOAD_CONFIG = {
  COPPER_MODELS,
  ENEMY_MODELS,
  STRUCTURE_MODELS,
  getAllModelUrls,
  getHighPriorityModelUrls,
  getMediumPriorityModelUrls,
  getLowPriorityModelUrls,
  getModelUrlsByPriority,
  getModelStats,
};