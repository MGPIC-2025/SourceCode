import { getAssetUrl } from './resourceLoader.js';
export const copperNameMap = {
  咝咝: 'spark',
  拉斐尔: 'syrup',
  波普尔: 'bubble',
  菲尼: 'glimmer',
  卷卷: 'turner',
  波波: 'wrench',
  公输: 'artifex',
  特斯拉: 'coil',
  丁格: 'drillbit',
  小卯: 'quickhand',
  阿磐: 'rocky',
  卫斯理: 'wesley',
  大贝尔: 'bell',
  团团: 'tumble',
  铿铿: 'chief',
  米洛: 'gyro',
  杰克: 'tricky',
  格洛克: 'pendulum',
  溜溜: 'yoyo',
  卡琳: 'karin',
  絮絮: 'murmur',
  啾啾: 'melody',
  库克: 'clawster',
  鼹鼠的地洞: 'diggs',
  蜜拉: 'hive',
};
export const copperTypeFolderMap = {
  IronWall: 'iron_wall',
  Arcanist: 'arcanist',
  Mechanic: 'mechanic',
  Resonator: 'resonator',
  CraftsMan: 'craftsman',
};
export const structureNameMap = {
  铆接壁垒: 'rivet_barrier',
  齿轮箭塔: 'gear_arrow_tower',
  心源矿钻: 'heart_source_mineral_drill',
  蒸汽矿车: 'steam_mining_car',
  充能线圈: 'charging_coil',
  维修工坊: 'repair_workshop',
  镜光折射塔: 'mirro_light_refraction_tower',
  共鸣警钟: 'resonance_alarm_bell',
  风暴铁砧: 'storm_anvil',
  自动装填炮: 'automatic_loading_gun',
};
export const resourceTypeMap = {
  RefinedCopper: 'refined_copper_ingot',
  ResonantCrystal: 'resonant_star_crystal',
  HeartCrystalDust: 'heart_crystal_dust',
  RecallGear: 'recall_gear',
  SpiritalSpark: 'spiritual_spark',
};
export const RESOURCE_META = {
  HeartCrystalDust: {
    name: '心晶尘',
    icon: getAssetUrl('resource/heart_crystal_dust.webp'),
  },
  RecallGear: {
    name: '回响齿轮',
    icon: getAssetUrl('resource/recall_gear.webp'),
  },
  ResonantCrystal: {
    name: '共鸣星晶',
    icon: getAssetUrl('resource/resonant_star_crystal/resonant_star_crystal.webp'),
  },
  RefinedCopper: {
    name: '精炼铜锭',
    icon: getAssetUrl('resource/refined_copper_ingot/refined_copper_ingot.webp'),
  },
  SpiritalSpark: {
    name: '灵性火花',
    icon: getAssetUrl('resource/spiritual_spark.webp'),
  },
};
export function getCopperEnglishName(chineseName) {
  return copperNameMap[chineseName] || chineseName.toLowerCase();
}
export function getCopperTypeFolder(copperType) {
  return copperTypeFolderMap[copperType] || copperType.toLowerCase();
}
export function getStructureEnglishName(chineseName) {
  return structureNameMap[chineseName] || chineseName.toLowerCase().replace(/\s+/g, '_');
}
export function getResourceFolderName(resourceType) {
  return resourceTypeMap[resourceType] || resourceType.toLowerCase();
}
export function getItemName(item) {
  if (Array.isArray(item?.item_type) && item.item_type[0] === 'Resource') {
    const resourceType = item.item_type[1];
    return RESOURCE_META[resourceType]?.name || resourceType;
  } else if (Array.isArray(item?.item_type) && item.item_type[0] === 'Equipment') {
    return '装备';
  }
  return '未知物品';
}
export function getItemIcon(item) {
  if (Array.isArray(item?.item_type) && item.item_type[0] === 'Resource') {
    const resourceType = item.item_type[1];
    return RESOURCE_META[resourceType]?.icon || '';
  }
  return '';
}
export function getResourceName(resourceType) {
  return RESOURCE_META[resourceType]?.name || resourceType;
}
export function getResourceIcon(resourceType) {
  return RESOURCE_META[resourceType]?.icon || '';
}

