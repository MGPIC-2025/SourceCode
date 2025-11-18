import { emitEvent, onEvent, offEvent, EventTypes } from './utils/eventBus.js';
class MessageQueue {
  constructor() {
    this.queue = [];
    this.isProcessing = false;
    this.handlers = new Map();
    this.sceneContext = null;
  }
  setSceneContext(context) {
    this.sceneContext = context;
  }
  registerHandler(messageType, handler) {
    this.handlers.set(messageType, handler);
  }
  enqueue(message) {
    this.queue.push(message);
    if (!this.isProcessing) {
      this.processNext();
    }
  }
  async processNext() {
    if (this.queue.length === 0) {
      this.isProcessing = false;
      return;
    }
    this.isProcessing = true;
    const batchSize = 50;
    let processed = 0;
    while (this.queue.length > 0 && processed < batchSize) {
      const message = this.queue.shift();
      processed++;
      try {
        const { type_msg, content } = message;
        const handler = this.handlers.get(type_msg);
        if (handler) {
          const data = JSON.parse(content);
          const result = handler(data, this.sceneContext || {});
          if (result && typeof result.then === 'function') {
            await result;
          }
        }
      } catch (error) {
      }
    }
    if (this.queue.length > 0) {
      requestAnimationFrame(() => this.processNext());
    } else {
      this.isProcessing = false;
    }
  }
}
export const messageQueue = new MessageQueue();
function findModelById(models, id) {
  return models.find(m => m.id === id);
}
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
export function registerAllHandlers() {
  messageQueue.registerHandler(
    'handle_on_click_copper',
    async (data, context) => {
      const { copper, resources, has_attack_targets } = data;
      if (context.highlightSelectedCopper) {
        context.highlightSelectedCopper(copper.id);
      }
      if (context.onShowCopperInfo) {
        context.onShowCopperInfo(copper, resources, has_attack_targets);
      }
    }
  );
  messageQueue.registerHandler(
    'handle_on_click_enemy',
    async (data, context) => {
      const { enemy, resources, has_attack_targets } = data;
      const isOwned = enemy.owned || false;
      const copperLikeData = {
        id: enemy.id,
        now_health: enemy.now_health,
        can_move: isOwned ? enemy.can_move : false,
        can_attack: isOwned ? enemy.can_attack : false,
        can_summon: false,
        position: enemy.position,
        isEnemy: !isOwned,
        isOwnedEnemy: isOwned,
        copper: {
          copper_info: {
            name: enemy.enemy_base?.name || (isOwned ? '召唤物' : '敌人'),
          },
          attribute: {
            health: enemy.enemy_base.health,
            attack: enemy.enemy_base.attack,
            defense: enemy.enemy_base.defense,
            speed: enemy.enemy_base.speed,
          },
        },
      };
      if (context.highlightSelectedCopper) {
        context.highlightSelectedCopper(enemy.id);
      }
      if (context.onShowCopperInfo) {
        context.onShowCopperInfo(copperLikeData, resources, has_attack_targets);
      }
    }
  );
  messageQueue.registerHandler(
    'handle_on_click_structure',
    async (data, context) => {
      const { structure, resources } = data;
      const isOwned = structure.owned || false;
      if (context.highlightSelectedCopper) {
        context.highlightSelectedCopper(structure.id);
      }
      if (context.onShowStructureInfo) {
        context.onShowStructureInfo(structure, resources);
      }
    }
  );
  messageQueue.registerHandler('set_copper', async (data, context) => {
    const { id, position, copper } = data;
    if (!window.__ACTUAL_COPPER_IDS__) {
      window.__ACTUAL_COPPER_IDS__ = [];
    }
    window.__ACTUAL_COPPER_IDS__.push(copper.id);
    emitEvent(EventTypes.COPPER_ID_ADDED, copper.id);
    if (context.onSetCopper) {
      await context.onSetCopper(id, position, copper);
    }
  });
  messageQueue.registerHandler('set_enemy', async (data, context) => {
    const { id, position, enemy } = data;
    if (context.onSetEnemy) {
      context.onSetEnemy(id, position, enemy);
    }
    if (enemy.owned) {
      emitEvent(EventTypes.UPDATE_RESOURCES);
    }
  });
  messageQueue.registerHandler('set_material', async (data, context) => {
    const { id, position, material } = data;
    if (context.onSetMaterial) {
      await context.onSetMaterial(id, position, material);
    }
  });
  messageQueue.registerHandler('set_structure', async (data, context) => {
    const { id, position, structure } = data;
    if (context.onSetStructure) {
      await context.onSetStructure(id, position, structure);
    }
    if (structure.owned) {
      emitEvent(EventTypes.UPDATE_RESOURCES);
    }
  });
  messageQueue.registerHandler('remove_unit', async (data, context) => {
    const { id } = data;
    const model = findModelById(context.models || [], id);
    const isEnemyDeath = model && model.type === 'enemy' && !model.isOwned;
    const enemyPosition = isEnemyDeath ? model.position : null;
    if (model && model.object) {
      const cloneMaterial = (mat) => {
        if (Array.isArray(mat)) return mat.map(m => m.clone());
        return mat.clone();
      };
      model.object.traverse(child => {
        if (child.material) child.material = cloneMaterial(child.material);
      });
      const duration = 500;
      const startTime = performance.now();
      await new Promise(resolve => {
        function animate() {
          const elapsed = performance.now() - startTime;
          const progress = Math.min(elapsed / duration, 1);
          if (model.object) {
            const updateOpacity = (mat, opacity) => {
              if (Array.isArray(mat)) {
                mat.forEach(m => { m.transparent = true; m.opacity = opacity; });
              } else {
                mat.transparent = true;
                mat.opacity = opacity;
              }
            };
            model.object.traverse(child => {
              if (child.material) updateOpacity(child.material, 1 - progress);
            });
          }
          if (progress < 1) {
            requestAnimationFrame(animate);
          } else {
            resolve();
          }
        }
        animate();
      });
      if (context.scene) {
        context.scene.remove(model.object);
      }
      const disposeMaterial = (mat) => {
        const maps = ['map', 'lightMap', 'bumpMap', 'normalMap', 'specularMap', 'envMap', 'alphaMap', 'aoMap', 'displacementMap', 'emissiveMap', 'metalnessMap', 'roughnessMap'];
        const disposeMat = (m) => {
          maps.forEach(mapName => m[mapName]?.dispose());
          m.dispose();
        };
        if (Array.isArray(mat)) {
          mat.forEach(disposeMat);
        } else {
          disposeMat(mat);
        }
      };
      model.object.traverse(child => {
        child.geometry?.dispose();
        if (child.material) disposeMaterial(child.material);
      });
      if (context.models) {
        const index = context.models.indexOf(model);
        if (index > -1) {
          context.models.splice(index, 1);
        }
      }
      if (context.onClearState) {
        context.onClearState(id);
      }
      if (context.onRemoveHealthBar) {
        context.onRemoveHealthBar(id);
      }
      if (model.type === 'copper' && context.onRemoveCopper) {
        context.onRemoveCopper(id);
      }
    }
    if (isEnemyDeath && enemyPosition) {
      const handleResourcesUpdated = changes => {
        if (context.onShowResourceGain && Object.keys(changes).length > 0) {
          context.onShowResourceGain(enemyPosition, changes);
        }
      };
      onEvent(EventTypes.RESOURCES_UPDATED, handleResourcesUpdated);
      emitEvent(EventTypes.UPDATE_RESOURCES);
      setTimeout(() => {
        offEvent(EventTypes.RESOURCES_UPDATED, handleResourcesUpdated);
      }, 1000);
    }
  });
  messageQueue.registerHandler('change_direction', async (data, context) => {
    const { id, direction } = data;
    const model = findModelById(context.models || [], id);
    if (!model?.object) return;
    const rotationMap = { PositiveY: 0, PositiveX: Math.PI / 2, NegativeY: Math.PI, NegativeX: -Math.PI / 2 };
    const targetRotation = rotationMap[direction] ?? 0;
    let startRotation = Math.atan2(Math.sin(model.object.rotation.y), Math.cos(model.object.rotation.y));
    let rotationDiff = targetRotation - startRotation;
    if (rotationDiff > Math.PI) rotationDiff -= 2 * Math.PI;
    else if (rotationDiff < -Math.PI) rotationDiff += 2 * Math.PI;
    const duration = 300;
    const startTime = performance.now();
    await new Promise(resolve => {
      function animate() {
        const progress = Math.min((performance.now() - startTime) / duration, 1);
        if (model.object) {
          model.object.rotation.y = startRotation + rotationDiff * (1 - Math.pow(1 - progress, 2));
        }
        if (progress < 1) {
          requestAnimationFrame(animate);
        } else {
          model.object && (model.object.rotation.y = targetRotation);
          resolve();
        }
      }
      animate();
    });
  });
  messageQueue.registerHandler('move_to', async (data, context) => {
    const { id, to } = data;
    const model = findModelById(context.models || [], id);
    if (!model?.object || !context.gridCellSize) return;
    const [gridX, gridZ] = to;
    model.position = [gridX, gridZ];
    context.onMoveStart?.(id, model);
    if (context.animateModelMove) {
      await new Promise(resolve => {
        context.animateModelMove(model, { x: gridX, y: model.object.position.y, z: gridZ }, resolve);
      });
    }
    context.onMoveComplete?.(id);
  });
  const createDisplayHandler = (key, callbackName) => (data, context) => {
    const value = data[key];
    const boolValue = value === 'true' || value === true;
    context[callbackName]?.(data.id, boolValue);
  };
  messageQueue.registerHandler('display_can_move', createDisplayHandler('can_move', 'onDisplayCanMove'));
  messageQueue.registerHandler('display_can_attack', createDisplayHandler('can_attack', 'onDisplayCanAttack'));
  messageQueue.registerHandler('display_can_summon', createDisplayHandler('can_summon', 'onDisplayCanSummon'));
  messageQueue.registerHandler('update_health', (data, context) => {
    context.onUpdateHealth?.(data.id, data.now_health, data.max_health);
  });
  messageQueue.registerHandler('clear_state', (data, context) => {
    context.onClearState?.(data.id);
  });
  messageQueue.registerHandler('animate_move', async (data, context) => {
    const { id } = data;
    const model = findModelById(context.models || [], id);
    if (!model) {
      return;
    }
    if (window.disableAutoFocus) {
      return;
    }
    const followEnemies =
      context.followEnemies !== undefined ? context.followEnemies : false;
    if (model.type === 'enemy' && !followEnemies) {
      return;
    }
    if (context.camera && context.focusOnModel) {
      const focusData = context.focusOnModel(
        model.object,
        context.camera,
        context.controls
      );
      if (context.focusState) {
        context.focusState.focusPosition = focusData.focusPosition;
        context.focusState.focusTarget = focusData.focusTarget;
        context.focusState.lerpFactor = focusData.lerpFactor;
      }
      await delay(1000);
    }
  });
  messageQueue.registerHandler('animate_reset', async (data, context) => {
    if (context.camera && context.controls) {
      const targetPos = { x: 0, y: 2, z: 5 };
      const targetLookAt = { x: 0, y: 0, z: 0 };
      if (context.focusState) {
        context.focusState.focusPosition = targetPos;
        context.focusState.focusTarget = targetLookAt;
        context.focusState.lerpFactor = 0.08;
      }
      await delay(1000);
    }
  });
  messageQueue.registerHandler('put_map_block', (data, context) => {
    context.onPutMapBlock?.(data.position);
  });
  messageQueue.registerHandler('put_room_blocks', async (data, context) => {
    if (!context.onPutMapBlock) return;
    const [roomX, roomY] = data.room_position;
    const blocksPerFrame = 32;
    let createdBlocks = 0;
    for (let x = 0; x < data.size; x++) {
      for (let y = 0; y < data.size; y++) {
        context.onPutMapBlock([roomX + x, roomY + y]);
        if (++createdBlocks % blocksPerFrame === 0) {
          await new Promise(resolve => requestAnimationFrame(resolve));
        }
      }
    }
  });
  messageQueue.registerHandler('put_resource_marker', (data, context) => {
    context.onPutResourceMarker?.(data.position);
  });
  messageQueue.registerHandler('clear_resource_marker', (data, context) => {
    context.onClearResourceMarker?.(data.position);
  });
  const blockCounts = { move: 0, attack: 0, summon: 0 };
  const createBlockHandler = (type, callbackName) => (data, context) => {
    blockCounts[type]++;
    context[callbackName]?.(data.position);
  };
  messageQueue.registerHandler('set_move_block', createBlockHandler('move', 'onSetMoveBlock'));
  messageQueue.registerHandler('set_attack_block', createBlockHandler('attack', 'onSetAttackBlock'));
  messageQueue.registerHandler('set_can_summon_blocks', createBlockHandler('summon', 'onSetCanSummonBlock'));
  let clearBlockCount = 0;
  let lastClearTime = Date.now();
  messageQueue.registerHandler('clear_block', (data, context) => {
    context.onClearBlock?.(data.position);
    clearBlockCount++;
    const now = Date.now();
    if (now - lastClearTime > 500) {
      clearBlockCount = 0;
      Object.keys(blockCounts).forEach(key => blockCounts[key] = 0);
    }
    lastClearTime = now;
  });
  messageQueue.registerHandler('attack_complete', (data, context) => {
    context.onAttackComplete?.(data.id);
  });
  messageQueue.registerHandler('on_game_round_pass', () => {});
  messageQueue.registerHandler('craft_success', (data, context) => {
    context.onCraftResult?.(true, data.message || '合成成功');
  });
  messageQueue.registerHandler('craft_failed', (data, context) => {
    context.onCraftResult?.(false, data.message || '合成失败');
  });
  ['cannot_pick_up_item', 'equipment_slot_full', 'inventory_full'].forEach(type => {
    messageQueue.registerHandler(type, () => {});
  });
  messageQueue.registerHandler('resource_not_enough', (data, context) => {
    const resourceNames = {
      HeartCrystalDust: '心源晶尘',
      RecallGear: '回响齿轮',
      SpiritalSpark: '灵性火花',
      RefinedCopper: '精炼铜锭',
      ResonantCrystal: '谐振星晶',
    };
    let message = '资源不足';
    if (Array.isArray(data.missing) && data.missing.length > 0) {
      const missingList = data.missing.map(item => {
        const name = resourceNames[item.type] || item.type;
        return `${name} (缺少 ${item.needed - item.current})`;
      }).join('、');
      message = `资源不足: ${missingList}`;
    }
    context.onResourceNotEnough?.(message);
  });
  messageQueue.registerHandler('summon_failed', (data, context) => {
    context.onSummonFailed?.(data.message || '召唤失败');
  });
  messageQueue.registerHandler('summon_expired', () => {});
  messageQueue.registerHandler('get_summon_menu', (data, context) => {
    context.onShowSummonMenu?.(data.contents);
  });
  messageQueue.registerHandler('get_structure_menu', (data, context) => {
    if (!data.contents?.length) return;
    const filteredContents = data.contents.filter(s => s.name !== '充能线圈');
    context.onShowStructureMenu?.(filteredContents);
  });
  messageQueue.registerHandler('drill_resource_generate', (data, context) => {
    context.onShowResourceGain?.(data.position, { [data.resource_type]: parseInt(data.amount) });
    emitEvent(EventTypes.UPDATE_RESOURCES);
  });
  messageQueue.registerHandler('game_over', (data, context) => {
    context.onGameOver?.();
  });
  messageQueue.registerHandler('success', (data, context) => {
    context.onGameSuccess?.();
  });
}
