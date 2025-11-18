///|
/// 处理游戏开始事件（初始化游戏并放置玩家选择的铜偶）
///
/// 该函数是游戏开始的入口点，负责初始化游戏实例、创建玩家选择的战斗铜偶、
/// 将铜偶放置到起始位置、设置铜偶朝向，并初始化游戏状态。前端需要提供一个
/// 界面让玩家从铜偶仓库中选择三个铜偶，然后传递它们的ID到后端。
///
/// 参数说明：
/// - ids: 玩家选择的三个铜偶的ID数组，必须包含恰好3个有效的铜偶ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 从全局仓库中获取三个铜偶的原始数据
/// 2. 创建三个战斗铜偶实例，分别放置在起始位置 (0, 3), (0, 4), (0, 5)
/// 3. 创建新的游戏实例并设置到 current_game
/// 4. 获取地图的第一个房间（起始房间）
/// 5. 将三个铜偶添加到房间的对应位置作为占用者
/// 6. 广播房间内容到前端（地图块、敌人和铜偶）
/// 7. 设置三个铜偶的朝向为正Y方向（朝向前方）
/// 8. 更新三个铜偶的状态显示（可移动、可攻击等）
///
/// 前端要求：
/// - 需要提供一个界面让玩家从铜偶仓库中选择三个铜偶
/// - 界面需要显示可用的铜偶列表
/// - 选择完成后传递三个铜偶的ID数组到后端
///
/// 使用场景：
/// - 玩家点击"开始游戏"按钮时
/// - 游戏初始化时
///
/// 注意事项：
/// - ids 数组必须包含恰好3个有效的铜偶ID
/// - 如果ID无效或铜偶不存在，会导致程序错误
/// - 起始位置是硬编码的，未来可能需要配置化
/// - 所有铜偶初始朝向为正Y方向（朝向前方）
fn handle_on_game_start(ids : Array[Int]) -> Unit {
  let warehouse = @global.global.val.warehouse
  let copper_1 = BattleCopper::new(warehouse.get_copper(ids[0]), ids[0], (0, 3))
  let copper_2 = BattleCopper::new(warehouse.get_copper(ids[1]), ids[1], (0, 4))
  let copper_3 = BattleCopper::new(warehouse.get_copper(ids[2]), ids[2], (0, 5))
  current_game.val = Some(Game::new())
  let map = force_get_current_map()
  let first_room = map.rooms[0]
  first_room.blocks[0][3].occupant = Copper(copper_1)
  first_room.blocks[0][4].occupant = Copper(copper_2)
  first_room.blocks[0][5].occupant = Copper(copper_3)

  // 广播房间内容（地图块、敌人和铜偶）
  // 由于 Map_::new 使用了 add_room_silent，这是唯一一次广播
  broadcast_room_content(first_room)
  change_direction(copper_1.id, PositiveY)
  change_direction(copper_2.id, PositiveY)
  change_direction(copper_3.id, PositiveY)

  // 显示铜偶的初始状态圈（绿圈和红圈）
  copper_1.update_move_and_attack_and_summon_status()
  copper_2.update_move_and_attack_and_summon_status()
  copper_3.update_move_and_attack_and_summon_status()
}

///|
/// 处理游戏回合结束事件（重置游戏状态并执行回合结束逻辑）
///
/// 该函数在玩家回合结束时被调用，负责清理当前回合的状态、重置所有单位的
/// 行动能力、执行敌人AI、重置摄像机视角，并处理回合结束时的特殊事件（如
/// 生成敌人和资源产出）。这是游戏回合循环的核心函数。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程（按顺序）：
/// 1. reset_all_blocks(): 清除所有显示的地块状态（攻击范围、移动范围、召唤范围等）
/// 2. reset_states(): 恢复所有单位的行动状态（铜偶、友方召唤物、建筑的 can_move、can_attack 等）
/// 3. enemy_ai(): 执行所有野生敌人的AI逻辑（攻击、移动）
/// 4. animate_reset(): 重置摄像机视角到默认位置
/// 5. summon_enemy_while_game_round_pass(): 根据充能线圈生成新敌人（概率性）
/// 6. resource_generate(): 处理资源产出（如心源矿钻产出资源）
///
/// 使用场景：
/// - 玩家点击"结束回合"按钮时
/// - 玩家回合时间耗尽时
/// - 需要强制结束回合时
///
/// 注意事项：
/// - 函数执行顺序很重要，不要随意调整
/// - 敌人AI在状态重置后执行，确保敌人有完整的行动能力
/// - 资源产出在回合结束时统一处理
/// - 摄像机重置让玩家看到全局视角
fn handle_game_round_pass() -> Unit {
  reset_all_blocks()
  reset_states()
  enemy_ai()
  animate_reset()
  summon_enemy_while_game_round_pass()
  resource_generate()
}

///|
/// 处理游戏结束事件（清理游戏状态）
///
/// 该函数在游戏结束时被调用，负责清理所有游戏相关的全局状态。函数会将当前
/// 游戏实例设置为 None，并重置所有游戏标志位（BOSS生成标志、特定敌人击杀标志等）。
/// 这是游戏状态清理的入口点。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 清理内容：
/// - current_game.val = None: 清除当前游戏实例
/// - boss_borned.val = false: 重置BOSS生成标志
/// - taotle_killed.val = false: 重置特定敌人（饕餮）击杀标志
/// - xtale_killed.val = false: 重置特定敌人（夏特拉）击杀标志
///
/// 使用场景：
/// - 玩家所有铜偶被击败时（游戏失败）
/// - 玩家完成关卡目标时（游戏胜利）
/// - 玩家主动退出游戏时
/// - 需要重置游戏状态时
///
/// 注意事项：
/// - 函数只清理游戏实例和标志位，不清理战斗单位（它们会在其他地方清理）
/// - 确保在调用此函数前所有必要的清理工作已完成
/// - 游戏结束后需要重新调用 handle_on_game_start 才能开始新游戏
fn handle_on_game_over() -> Unit {
  current_game.val = None
  boss_borned.val = false
  taotle_killed.val = false
  xtale_killed.val = false
}

///|
/// 清除所有显示的地块状态指示器
///
/// 该函数用于在回合结束时清除所有显示在地图上的状态指示器，包括攻击范围、
/// 移动范围、传送范围和召唤范围。函数会遍历所有已设置的地块状态，逐个清除
/// 显示，并清空对应的状态集合。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 清除内容（按顺序）：
/// 1. 攻击范围地块（setted_attack_blocks）: 清除所有红色攻击范围指示器
/// 2. 移动范围地块（setted_move_blocks）: 清除所有绿色移动范围指示器
/// 3. 传送范围地块（setted_transfer_blocks）: 清除所有传送范围指示器
/// 4. 召唤范围地块（setted_can_summon_blocks）: 清除所有黄色召唤范围指示器
///
/// 执行逻辑：
/// - 对于每种类型的地块状态，遍历对应的集合
/// - 对每个地块调用 clear_block() 清除前端显示
/// - 清空对应的集合，准备下一回合使用
///
/// 使用场景：
/// - 回合结束时清除所有状态显示
/// - 需要重置地图显示时
/// - 游戏状态清理时
///
/// 注意事项：
/// - 函数会清除所有类型的地块状态，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - 确保在状态重置前调用，避免状态残留
fn reset_all_blocks() -> Unit {
  for attack_block in setted_attack_blocks {
    clear_block(attack_block)
  }
  setted_attack_blocks.clear()
  for move_block in setted_move_blocks {
    clear_block(move_block)
  }
  setted_move_blocks.clear()
  for transfer_block in setted_transfer_blocks {
    clear_block(transfer_block)
  }
  setted_transfer_blocks.clear()
  for summon_block in setted_can_summon_blocks {
    clear_block(summon_block)
  }
  setted_can_summon_blocks.clear()
}

///|
/// 在游戏回合结束时根据充能线圈概率性生成新敌人
///
/// 该函数在回合结束时检查地图上是否存在充能线圈建筑，如果存在且房间未满，
/// 则有20%的概率在房间内随机生成一个新敌人。生成的敌人等级与房间等级相同，
/// 位置随机选择房间内的空位置。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 生成逻辑：
/// 1. 首先进行概率检查：20%的概率执行生成逻辑（check_probability(0.2)）
/// 2. 遍历地图上的所有房间
/// 3. 跳过已满的房间（Room::is_full(room)）
/// 4. 检查房间中心位置 (4, 4) 是否有充能线圈建筑
/// 5. 如果有充能线圈，获取房间等级并生成对应等级的敌人
/// 6. 获取房间内所有空位置（Room::get_empty_positions）
/// 7. 随机选择一个空位置作为生成位置
/// 8. 计算全局坐标（房间坐标 + 房间内坐标）
/// 9. 创建敌人实例并添加到地图和房间
/// 10. 通知前端显示新敌人（set_enemy）
///
/// 使用场景：
/// - 回合结束时自动执行
/// - 需要根据充能线圈生成敌人时
///
/// 注意事项：
/// - 生成概率固定为20%，每次回合结束独立判定
/// - 只检查房间中心位置的充能线圈，其他位置的充能线圈不会触发
/// - 生成的敌人等级与房间等级相同
/// - 如果房间已满，不会生成敌人
/// - 位置选择是完全随机的，可能生成在房间边缘
fn summon_enemy_while_game_round_pass() -> Unit {
  if check_probability(0.2) {
    let map = force_get_current_map()
    for room in map.rooms {
      if Room::is_full(room) {
        continue
      }
      if room.blocks[4][4].occupant is Structure(structure) &&
        structure.structure_base.name == "充能线圈" {
        let level = room.level
        let enemy = summon_enemy(level)
        // 不再用 escape_set 来判断位置了，直接反选空坐标
        let empty_positions = Room::get_empty_positions(room)
        let position = empty_positions[summon_random_number(
            0,
            empty_positions.length() - 1,
          )]
        let global_position = (
          room.index_position.0 + position.0,
          room.index_position.1 + position.1,
        )
        let enemy = Enemy::new(enemy, global_position, false)
        room.blocks[position.0][position.1].occupant = Enemy(enemy)
        set_enemy(enemy, enemy.id, global_position)
      }
    }
  }
}

///|
/// 重置所有单位的行动状态（恢复回合开始时的状态）
///
/// 该函数用于在回合结束时重置所有单位的行动能力，包括战斗铜偶、友方召唤物
/// 和玩家建筑。函数会根据单位类型和属性，恢复它们的可移动、可攻击、可召唤、
/// 可建造等状态，并更新前端显示。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 重置内容（按单位类型）：
/// 1. 战斗铜偶（battle_copper_map）:
///    - can_move: 重置为 true（所有铜偶都可以移动）
///    - can_attack: 根据铜偶类型设置（工匠和共鸣者为 false，其他为 true）
///    - can_summon: 只有共鸣者类型为 true，其他为 false
///    - can_build: 只有工匠类型为 true，其他为 false
///    - 调用 update_move_and_attack_and_summon_status() 更新前端显示
///
/// 2. 友方召唤物（enemy_map 中 owned = true 的敌人）:
///    - can_move: 重置为 true
///    - can_attack: 重置为 true
///    - 调用 update_move_and_attack_and_summon_status() 更新前端显示
///
/// 3. 玩家建筑（structure_map 中 owned = true 的建筑）:
///    - can_attack: 如果建筑有攻击能力（structure_base.can_attack），重置为 true
///    - 调用 update_move_and_attack_and_summon_status() 更新前端显示
///
/// 使用场景：
/// - 回合结束时恢复所有单位状态
/// - 需要重置游戏状态时
///
/// 注意事项：
/// - 函数会重置所有单位的行动能力，确保新回合开始时单位可以行动
/// - 状态重置基于单位类型和属性，不是简单的全部设为 true
/// - 重置后会立即更新前端显示，确保UI同步
/// - 只重置玩家拥有的单位，敌方单位不受影响
fn reset_states() -> Unit {
  // 恢复铜偶状态
  for battle_copper in battle_copper_map.values() {
    battle_copper.can_move = true
    // 根据铜偶类型设置攻击能力：工匠和共鸣者不能攻击
    battle_copper.can_attack = match battle_copper.copper.copper_type {
      CraftsMan | Resonator => false
      _ => true
    }
    battle_copper.can_summon = battle_copper.copper.copper_type is Resonator
    battle_copper.can_build = battle_copper.copper.copper_type is CraftsMan
    battle_copper.update_move_and_attack_and_summon_status()
  }

  // 恢复友方召唤物状态
  for enemy in enemy_map.values() {
    if enemy.owned {
      enemy.can_move = true
      enemy.can_attack = true
      enemy.update_move_and_attack_and_summon_status()
    }
  }

  // 恢复建筑状态
  for structure in structure_map.values() {
    if structure.owned {
      if structure.structure_base.can_attack {
        structure.can_attack = true
      }
      structure.update_move_and_attack_and_summon_status()
    }
  }
}

///|
/// 执行所有野生敌人的AI逻辑（自动攻击和移动）
///
/// 该函数实现了野生敌人的AI系统，负责让所有非玩家拥有的敌人自动执行行动。
/// AI逻辑分为两个阶段：优先攻击阶段和移动阶段。如果敌人在攻击范围内有可攻击
/// 目标，则直接攻击；如果没有可攻击目标，则寻找最近的目标并移动靠近。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// AI执行流程（对每个野生敌人）：
/// 1. 获取敌人的攻击目标列表（get_attack_targets）
/// 2. 如果攻击范围内有目标（attack_targets.length() > 0）:
///    a. 选择第一个目标进行攻击
///    b. 触发摄像机动画（animate_move）
///    c. 根据目标类型执行攻击：
///       - Enemy（友方召唤物）: 应用攻击，如果击杀则移除
///       - Copper（玩家铜偶）: 应用攻击，如果击杀则减少铜偶生命数并移除，如果所有铜偶被击败则游戏结束
///       - Structure（玩家建筑）: 应用攻击，如果击杀则移除
///    d. 如果目标未被击杀，更新目标的生命值显示
///
/// 3. 如果攻击范围内没有目标:
///    a. 查找最近的可攻击目标（find_nearest_attack_target）
///    b. 如果找到目标，使用路径查找算法计算下一步移动位置
///    c. 如果找到可行路径，执行移动：
///       - 触发摄像机动画（animate_move）
///       - 从地图移除旧位置
///       - 更新敌人位置
///       - 在地图添加新位置
///       - 根据移动方向改变敌人朝向
///       - 通知前端执行移动动画（move_to）
///
/// 使用场景：
/// - 回合结束时自动执行
/// - 需要执行敌人AI时
///
/// 注意事项：
/// - 只处理野生敌人（owned = false），友方召唤物由玩家控制
/// - 攻击优先级高于移动，有目标就攻击
/// - 移动使用路径查找算法，考虑障碍物和移动范围
/// - 敌人移动后会更新朝向，面向移动方向
/// - 如果所有玩家铜偶被击败，会触发游戏结束
fn enemy_ai() -> Unit {
  let map = force_get_current_map()
  // 野生敌人AI：寻找攻击目标和移动（友方召唤物由玩家控制，不执行AI）
  let enemys = enemy_map.values().iter().filter(enemy => enemy.owned == false)
  for enemy in enemys {
    // 跳过友方召唤物（由玩家控制）
    let attack_targets = enemy.get_attack_targets(map)
    // 如果攻击范围内有可以攻击的目标，则直接开始攻击
    if attack_targets.length() > 0 {
      let attack_target = attack_targets[0]
      animate_move(enemy.id)
      match attack_target {
        Enemy(target_enemy) => {
          // 野生敌人攻击友方召唤物
          let result = target_enemy.apply_attack(enemy.enemy_base.attack)
          if result {
            enemy_map.remove(target_enemy.id)
            remove_unit(target_enemy.id)
            map.remove_occupant(target_enemy.position)
          } else {
            // 更新友方召唤物血量显示
            update_health(
              target_enemy.id,
              target_enemy.now_health,
              target_enemy.enemy_base.health,
            )
          }
        }
        Copper(copper) => {
          let result = copper.apply_attack(enemy.enemy_base.attack)
          if result {
            copper.copper.live_left -= 1
            battle_copper_map.remove(copper.id)
            remove_unit(copper.id)
            map.remove_occupant(copper.position)
            if battle_copper_map.length() == 0 {
              game_over()
            }
          } else {
            // 更新铜偶血量显示
            update_health(
              copper.id,
              copper.now_health,
              copper.copper.attribute.health,
            )
          }
        }
        Structure(structure) => {
          let result = structure.apply_attack(enemy.enemy_base.attack)
          if result {
            structure_map.remove(structure.id)
            remove_unit(structure.id)
            map.remove_occupant(structure.position)
          } else {
            // 更新建筑血量显示
            update_health(
              structure.id,
              structure.now_health,
              structure.structure_base.health,
            )
          }
        }
      }
    } else {
      let target = enemy.find_nearest_attack_target()
      if target is Some(target) {
        let target_position = target.get_position_from_can_attack_target()
        let path_finder_map = PathFinderMap::new(map)
        let next_position = PathFinderMap::get_next_step(
          path_finder_map,
          enemy.position,
          target_position,
          enemy.enemy_base.speed,
          enemy.enemy_base.attack_range,
        )
        if next_position is Some(next_position) {
          animate_move(enemy.id)
          // 保存旧位置用于计算方向
          let old_position = enemy.position
          // 先从地图移除旧位置
          map.remove_occupant(enemy.position)
          // 更新敌人位置
          enemy.position = next_position
          // 在地图添加新位置
          map.add_occupant(enemy.position, Enemy(enemy))
          // 根据位置改变敌人的朝向
          change_direction(
            enemy.id,
            convert_direction_to_unit_direction(
              get_direction_by_position(old_position, next_position),
            ),
          )
          // 最后调用前端移动
          move_to(enemy.id, next_position)
        }
      }
    }
  }
}

///|
/// 处理回合结束时的资源产出逻辑
///
/// 该函数在回合结束时检查所有玩家建筑，如果建筑是"心源矿钻"，则产出对应的
/// 资源。每个心源矿钻每回合产出2个对应类型的资源，并通知前端显示资源产出特效。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 产出逻辑：
/// 1. 遍历所有建筑（structure_map.values()）
/// 2. 检查建筑名称是否为"心源矿钻"
/// 3. 如果是指定建筑，获取建筑的资源类型（resource_type）
/// 4. 如果资源类型有效（Some(resource_type)）:
///    a. 向全局资源背包添加2个对应类型的资源
///    b. 构造资源产出消息，包含位置、资源类型、数量
///    c. 通过消息系统广播到前端，触发资源产出特效显示
///
/// 产出规则：
/// - 每个心源矿钻每回合固定产出2个资源
/// - 产出资源类型由建筑配置决定（structure.resource_type）
/// - 产出位置为建筑所在位置，用于显示特效
///
/// 使用场景：
/// - 回合结束时自动执行
/// - 需要处理资源产出时
///
/// 注意事项：
/// - 只有"心源矿钻"建筑会产出资源，其他建筑不受影响
/// - 产出数量固定为2，未来可能需要配置化
/// - 资源直接添加到全局背包，不需要玩家手动收集
/// - 前端会显示资源产出特效，提升游戏体验
fn resource_generate() -> Unit {
  for structure in structure_map.values() {
    if structure.structure_base.name == "心源矿钻" {
      let resource_type = structure.resource_type
      if resource_type is Some(resource_type) {
        global.val.bag.resources.add_resource(resource_type, 2)
        // 通知前端显示资源产出特效
        msg_info.broadcast({
          type_msg: "drill_resource_generate",
          content: (
            {
              "position": structure.position,
              "resource_type": resource_type.to_string(),
              "amount": 2,
            } : Json).stringify(),
        })
      }
    }
  }
}
