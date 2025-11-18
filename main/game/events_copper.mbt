///|
/// 处理铜偶被点击事件（显示铜偶信息和状态）
///
/// 该函数在玩家点击战斗中的铜偶时被调用，负责清除所有当前显示的范围指示器、
/// 获取铜偶信息、检查是否有可攻击目标，并将信息发送到前端用于渲染信息栏。
/// 同时会更新铜偶的状态显示（可移动、可攻击、可召唤、可建造的圈圈指示器）。
///
/// 参数说明：
/// - id: 被点击的铜偶的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有当前显示的范围指示器（移动、攻击、召唤范围）
/// 2. 根据ID获取战斗铜偶实例
/// 3. 获取当前地图实例
/// 4. 检查铜偶是否有可攻击目标（has_attack_targets）
/// 5. 构造消息并广播到前端，包含铜偶信息和是否有攻击目标
/// 6. 更新铜偶的状态显示（显示绿色/红色/黄色圈圈）
///
/// 使用场景：
/// - 玩家点击战斗中的铜偶时
/// - 需要查看铜偶信息时
/// - 需要切换选中的铜偶时
///
/// 注意事项：
/// - 点击铜偶会清除所有范围显示，避免视觉混乱
/// - 消息包含完整的铜偶JSON数据，前端可以渲染详细信息
/// - has_attack_targets 用于前端判断是否显示攻击按钮
/// - 状态圈圈会立即更新，显示铜偶当前可执行的操作
fn handle_on_click_copper(id : Int) -> Unit {
  // 清除所有范围显示（切换铜偶时）
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let battle_copper = get_battle_copper_by_id(id)
  let map = force_get_current_map()
  let has_attack_targets = !battle_copper.get_can_attack(map).is_empty()
  msg_info.broadcast({
    type_msg: "handle_on_click_copper",
    content: (
      {
        "copper": get_battle_copper_by_id(id).to_json(),
        "has_attack_targets": has_attack_targets,
      } : Json).stringify(),
  })
  // 显示铜偶的状态圈圈（绿色/红色/黄色）
  battle_copper.update_move_and_attack_and_summon_status()
}

///|
/// 处理铜偶开始攻击事件（显示攻击范围）
///
/// 该函数在玩家点击攻击按钮或开始攻击操作时被调用，负责清除其他范围显示、
/// 计算铜偶的攻击目标，并在所有可攻击目标的位置显示红色攻击范围指示器。
/// 这帮助玩家直观地看到可以攻击哪些目标。
///
/// 参数说明：
/// - map: 当前游戏地图实例，用于查询位置和占用者信息
/// - id: 执行攻击的铜偶的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID获取战斗铜偶实例
/// 3. 计算铜偶的所有可攻击目标（get_can_attack）
/// 4. 遍历所有可攻击目标，获取目标位置
/// 5. 在每个目标位置设置红色攻击范围指示器（set_attack_block）
/// 6. 将位置添加到已设置攻击范围的集合中（setted_attack_blocks）
///
/// 使用场景：
/// - 玩家点击攻击按钮时
/// - 需要显示攻击范围时
///
/// 注意事项：
/// - 函数会清除其他范围显示，确保只显示攻击范围
/// - 攻击范围指示器是红色的，用于区分移动范围（绿色）和召唤范围（黄色）
/// - 只有可攻击的目标位置会显示指示器
/// - 指示器会一直显示直到玩家取消攻击或执行攻击
fn handle_on_attack_start(map : Map_, id : Int) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let battle_copper = get_battle_copper_by_id(id)
  let attack_target = battle_copper.get_can_attack(map)
  for target in attack_target {
    let position = target.get_position_from_can_attack_target()
    set_attack_block(position)
    setted_attack_blocks.add(position)
  }
}

///|
/// 处理攻击结束或取消事件（清除攻击范围显示）
///
/// 该函数在玩家取消攻击操作或攻击完成后被调用，负责清除所有显示的红色攻击
/// 范围指示器。函数会遍历所有已设置攻击范围的位置，逐个清除显示，并清空
/// 对应的集合。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置攻击范围的位置（setted_attack_blocks）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Attack类型）
/// 4. 清空已设置攻击范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消攻击操作时
/// - 攻击完成后清除范围显示时
/// - 切换操作模式时（如从攻击切换到移动）
///
/// 注意事项：
/// - 函数会清除所有攻击范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
fn handle_on_attack_end() -> Unit {
  for position in setted_attack_blocks {
    clear_block(position)
    check_and_reset_block(position, Attack)
  }
  setted_attack_blocks.clear()
}

///|
/// 处理攻击实施事件（执行攻击并计算伤害）
///
/// 该函数在玩家选择攻击目标并确认攻击时被调用，负责执行完整的攻击流程：
/// 触发摄像机动画、获取目标、根据目标类型执行不同的攻击逻辑、处理击杀、
/// 更新状态，并清除攻击范围显示。这是攻击系统的核心函数。
///
/// 参数说明：
/// - id: 执行攻击的铜偶的唯一ID
/// - position: 攻击目标的位置坐标 (x, y)
/// - map: 当前游戏地图实例，用于查询目标信息
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 触发摄像机动画，聚焦到攻击的铜偶（animate_move）
/// 2. 根据ID获取战斗铜偶实例
/// 3. 从地图获取目标位置的占用者（get_occupant）
/// 4. 根据目标类型执行不同的攻击逻辑：
///    a. Enemy（敌人）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：添加掉落物品到背包、移除敌人、通知前端移除单位
///       - 如果未击杀：更新敌人生命值显示
///       - 检查BOSS击杀条件（饕餮、夏特拉），如果都击杀则游戏胜利
///    b. Copper（机械师铜偶，用于治疗）:
///       - 应用治疗效果（apply_mechanic_heal）
///       - 更新铜偶生命值显示
///    c. Structure（敌方建筑）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：移除建筑、通知前端移除单位
///       - 如果未击杀：更新建筑生命值显示
/// 5. 设置铜偶的 can_attack 为 false（本回合不能再攻击）
/// 6. 更新铜偶的状态显示
/// 7. 清除所有攻击范围指示器
/// 8. 如果攻击成功（目标不是空），发送攻击完成消息（attack_complete）
///
/// 使用场景：
/// - 玩家选择攻击目标并确认时
/// - 需要执行攻击逻辑时
///
/// 注意事项：
/// - 攻击会消耗铜偶的 can_attack 状态，本回合不能再攻击
/// - 击杀敌人会获得掉落物品，自动添加到背包
/// - BOSS击杀有特殊逻辑，需要两个BOSS都击杀才能胜利
/// - 攻击机械师铜偶是治疗效果，不是伤害
/// - 无论攻击成功与否，都会清除攻击范围显示
fn handle_on_attack_apply(id : Int, position : (Int, Int), map : Map_) -> Unit {
  // 攻击前将视角聚焦到铜偶
  animate_move(id)
  let battle_copper = get_battle_copper_by_id(id)
  let target = map.get_occupant(position)
  match target {
    Enemy(enemy) => {
      let result = enemy.apply_attack(battle_copper.attribute.attack)
      // 单位被击杀
      if result {
        global.val.bag.add_resource(enemy.get_drop_items())
        enemy_map.remove(enemy.id)
        remove_unit(enemy.id)
        map.remove_occupant(enemy.position)
        println("deeeebug"+(match force_get_current_map().get_occupant(enemy.position){
          Empty => "Empty"
          Enemy(_) => "Enemy"
          _ => "Other"
        }))
        if boss_borned.val == true {
          if enemy.enemy_base.name == "（BOSS）废械吞噬者·饕餮" {
            taotle_killed.val = true
          } else if enemy.enemy_base.name == "（BOSS）织网夫人·夏特拉" {
            xtale_killed.val = true
          }
          if taotle_killed.val == true && xtale_killed.val == true {
            success()
          }
        }
      } else {
        // 更新敌人血量显示
        update_health(enemy.id, enemy.now_health, enemy.enemy_base.health)
      }
      battle_copper.can_attack = false
      battle_copper.update_move_and_attack_and_summon_status()
    }
    Copper(copper) => {
      copper.apply_mechanic_heal(battle_copper.attribute.attack)
      // 更新铜偶血量显示
      update_health(
        copper.id,
        copper.now_health,
        copper.copper.attribute.health,
      )
      battle_copper.can_attack = false
      battle_copper.update_move_and_attack_and_summon_status()
    }
    Structure(structure) => {
      let result = structure.apply_attack(battle_copper.attribute.attack)
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
      battle_copper.can_attack = false
      battle_copper.update_move_and_attack_and_summon_status()
    }
    Empty => ()
    _ => abort("target is not enemy or copper")
  }
  // 无论如何都要清除攻击范围
  for position in setted_attack_blocks {
    clear_block(position)
    check_and_reset_block(position, Attack)
  }
  setted_attack_blocks.clear()
  // 只有成功攻击才发送完成消息
  if !(target is Empty) {
    attack_complete(id)
  }
}

///|
/// 处理移动开始事件（显示移动范围）
///
/// 该函数在玩家点击移动按钮或开始移动操作时被调用，负责清除其他范围显示、
/// 计算铜偶的可移动位置，并在所有可移动位置显示绿色移动范围指示器。这帮助
/// 玩家直观地看到可以移动到哪些位置。
///
/// 参数说明：
/// - map: 当前游戏地图实例，用于查询位置和占用情况
/// - id: 执行移动的铜偶的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID获取战斗铜偶实例
/// 3. 计算铜偶的所有可移动位置（get_can_move）
/// 4. 遍历所有可移动位置
/// 5. 在每个位置设置绿色移动范围指示器（set_move_block）
/// 6. 将位置添加到已设置移动范围的集合中（setted_move_blocks）
///
/// 使用场景：
/// - 玩家点击移动按钮时
/// - 需要显示移动范围时
///
/// 注意事项：
/// - 函数会清除其他范围显示，确保只显示移动范围
/// - 移动范围指示器是绿色的，用于区分攻击范围（红色）和召唤范围（黄色）
/// - 只有可移动的位置会显示指示器（考虑占用、边界、房间距离等）
/// - 指示器会一直显示直到玩家取消移动或执行移动
fn handle_on_move_start(map : Map_, id : Int) -> Unit {
  // 先清除之前的移动范围和攻击范围
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let battle_copper = get_battle_copper_by_id(id)
  let can_move = battle_copper.get_can_move(map)
  for position in can_move {
    set_move_block(position)
    setted_move_blocks.add(position)
  }
}

///|
/// 处理移动结束或取消事件（清除移动范围显示）
///
/// 该函数在玩家取消移动操作或移动完成后被调用，负责清除所有显示的绿色移动
/// 范围指示器。函数会遍历所有已设置移动范围的位置，逐个清除显示，并清空
/// 对应的集合。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置移动范围的位置（setted_move_blocks）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Move类型）
/// 4. 清空已设置移动范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消移动操作时
/// - 移动完成后清除范围显示时
/// - 切换操作模式时（如从移动切换到攻击）
///
/// 注意事项：
/// - 函数会清除所有移动范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
fn handle_on_move_end() -> Unit {
  for position in setted_move_blocks {
    clear_block(position)
    check_and_reset_block(position, Move)
  }
  setted_move_blocks.clear()
}

///|
/// 处理移动实施事件（执行移动并处理房间生成）
///
/// 该函数在玩家选择移动目标并确认移动时被调用，负责执行完整的移动流程：
/// 触发摄像机动画、处理房间内移动或新房间生成、更新铜偶位置和朝向、更新
/// 状态，并清除移动范围显示。这是移动系统的核心函数，包含复杂的房间生成逻辑。
///
/// 参数说明：
/// - id: 执行移动的铜偶的唯一ID
/// - position: 目标移动位置坐标 (x, y)
/// - map: 当前游戏地图实例，用于查询位置和房间信息
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 触发摄像机动画，聚焦到移动的铜偶（animate_move）
/// 2. 根据ID获取战斗铜偶实例
/// 3. 检查目标位置是否在当前已有的房间内（find_position_in_map）
///
/// 情况A：目标位置在已有房间内
///   a. 获取当前位置和房间信息（global_position_to_room_position）
///   b. 获取目标位置和房间信息
///   c. 从旧房间位置移除铜偶（设置为Empty）
///   d. 将铜偶添加到新房间位置（设置为Copper）
///   e. 更新铜偶的全局位置
///   f. 根据移动方向改变铜偶朝向（change_direction）
///   g. 通知前端执行移动动画（move_to）
///
/// 情况B：目标位置不在已有房间内（需要生成新房间）
///   a. 获取当前位置和房间信息
///   b. 计算新房间的索引位置和方向（get_room_direction_and_new_position）
///   c. 计算铜偶在新房间内的本地坐标
///   d. 生成新房间，排除铜偶位置来生成敌人（Room::new）
///   e. 将新房间添加到地图（Map_::add_room）
///   f. 从旧房间移除铜偶
///   g. 将铜偶放入新房间
///   h. 广播新房间内容到前端（broadcast_room_content）
///   i. 根据移动方向改变铜偶朝向
///   j. 更新铜偶的全局位置
///   k. 通知前端执行移动动画
///
/// 4. 设置铜偶的 can_move 为 false（本回合不能再移动）
/// 5. 更新铜偶的状态显示
/// 6. 清除所有移动范围指示器
///
/// 使用场景：
/// - 玩家选择移动目标并确认时
/// - 需要执行移动逻辑时
///
/// 注意事项：
/// - 移动会消耗铜偶的 can_move 状态，本回合不能再移动
/// - 移动到新位置会自动生成新房间，包含敌人和资源
/// - 新房间的等级根据房间数量计算（get_level_by_room_count）
/// - 铜偶移动后会更新朝向，面向移动方向
/// - 新房间生成后会立即广播到前端，显示完整内容
fn handle_on_move_apply(id : Int, position : (Int, Int), map : Map_) -> Unit {
  // 移动前将视角聚焦到铜偶
  animate_move(id)
  let battle_copper = get_battle_copper_by_id(id)
  if map.find_position_in_map(position) is Some(_) {
    // 如果仍在当前已有的房间内  
    // 移除旧位置的铜偶，并将其放到新位置
    let now_position = battle_copper.position
    // 将全局坐标转换为房间本地坐标
    let (now_room, now_local_pos) = map
      .global_position_to_room_position(now_position)
      .unwrap()
    let (target_room, target_local_pos) = map
      .global_position_to_room_position(position)
      .unwrap()
    now_room.blocks[now_local_pos.0][now_local_pos.1].occupant = Empty
    target_room.blocks[target_local_pos.0][target_local_pos.1].occupant = Occupant::Copper(
      battle_copper,
    )
    // 更新铜偶的位置
    battle_copper.position = position
    // 根据位置改变铜偶的朝向
    change_direction(
      id,
      convert_direction_to_unit_direction(
        get_direction_by_position(now_position, position),
      ),
    )
    // 移动铜偶到新位置
    move_to(id, position)
  } else {
    // 如果不在当前已有的房间内，则需要生成新的房间
    // 获取当前位置和当前房间
    let now_position = battle_copper.position
    let (now_room, now_local_pos) = map
      .global_position_to_room_position(now_position)
      .unwrap()
    // 获取新的房间索引位置和方向
    let (_, new_room_index) = Room::get_room_direction_and_new_position(
      now_room, position,
    )
    // 计算铜偶在新房间内的本地位置
    let new_local_x = position.0 - new_room_index.0
    let new_local_y = position.1 - new_room_index.1
    // 生成房间，将其加入地图，并排除铜偶的位置来生成敌人
    let new_room = Room::new(
      get_level_by_room_count(map.rooms.length() + 1),
      new_room_index,
      Set::from_array([(new_local_x, new_local_y)]),
    )
    Map_::add_room(map, new_room)
    // 移除旧房间的铜偶
    now_room.blocks[now_local_pos.0][now_local_pos.1].occupant = Empty
    // 将铜偶放入新房间
    new_room.blocks[new_local_x][new_local_y].occupant = Copper(battle_copper)
    // 广播新房间的内容到前端
    broadcast_room_content(new_room)
    // 根据位置改变铜偶的朝向（使用get_direction_by_position计算正确的朝向）
    change_direction(
      id,
      convert_direction_to_unit_direction(
        get_direction_by_position(now_position, position),
      ),
    )
    // 更新铜偶的位置（全局坐标）
    battle_copper.position = position
    // 移动铜偶到新位置（全局坐标）
    move_to(id, position)
  }
  battle_copper.can_move = false
  battle_copper.update_move_and_attack_and_summon_status()
  for position in setted_move_blocks {
    clear_block(position)
    check_and_reset_block(position, Move)
  }
  setted_move_blocks.clear()
}

// 共鸣者召唤流程：
// 1. 玩家点击共鸣者
// 2. 选择空位召唤敌人
// 3. 打开敌人召唤菜单
// 4. 玩家选择敌人
// 5. 敌人召唤到地图上

///|
/// 处理召唤开始事件（显示召唤范围）
///
/// 该函数在玩家点击召唤按钮或开始召唤操作时被调用，负责清除其他范围显示、
/// 计算共鸣者铜偶的可召唤位置，并在所有可召唤位置显示黄色召唤范围指示器。
/// 这帮助玩家直观地看到可以在哪些位置召唤新单位。
///
/// 参数说明：
/// - id: 执行召唤的铜偶的唯一ID（必须是共鸣者类型）
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID获取战斗铜偶实例
/// 3. 获取当前地图实例
/// 4. 计算铜偶的所有可召唤位置（get_summon_position）
/// 5. 遍历所有可召唤位置
/// 6. 在每个位置设置黄色召唤范围指示器（set_can_summon_blocks）
/// 7. 将位置添加到已设置召唤范围的集合中（setted_can_summon_blocks）
///
/// 使用场景：
/// - 玩家点击召唤按钮时（共鸣者铜偶）
/// - 需要显示召唤范围时
///
/// 注意事项：
/// - 只有共鸣者类型的铜偶才能召唤，其他类型调用此函数无意义
/// - 函数会清除其他范围显示，确保只显示召唤范围
/// - 召唤范围指示器是黄色的，用于区分移动范围（绿色）和攻击范围（红色）
/// - 只有可召唤的位置会显示指示器（必须是空位置且在地图范围内）
/// - 指示器会一直显示直到玩家取消召唤或执行召唤
fn handle_on_summon_start(id : Int) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let battle_copper = get_battle_copper_by_id(id)
  let map = force_get_current_map()
  let can_summon = battle_copper.get_summon_position(map)
  for position in can_summon {
    set_can_summon_blocks(position)
    setted_can_summon_blocks.add(position)
  }
}

///|
/// 处理召唤实施事件（执行召唤并消耗资源）
///
/// 该函数在玩家选择召唤位置和敌人类型并确认召唤时被调用，负责检查资源是否
/// 充足、消耗资源、创建友方召唤物（使用敌人外观）、将召唤物添加到地图，并
/// 更新状态。这是召唤系统的核心函数。
///
/// 参数说明：
/// - id: 执行召唤的铜偶的唯一ID（必须是共鸣者类型）
/// - position: 召唤位置坐标 (x, y)，必须是可召唤的位置
/// - map: 当前游戏地图实例，用于添加召唤物
/// - name: 要召唤的敌人名称，必须存在于 enemy_info_map 中
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 根据敌人名称获取敌人基础信息（enemy_info_map.get）
/// 2. 获取召唤所需的资源消耗（enemy_base.summon_cost）
/// 3. 根据ID获取战斗铜偶实例
/// 4. 检查资源是否充足（check_resource_cost）
/// 5. 如果资源充足：
///    a. 消耗资源（consume_resource_cost）
///    b. 创建友方召唤物（Enemy::new，owned = true）
///    c. 将召唤物添加到地图（map.add_occupant）
///    d. 通知前端显示召唤物（set_enemy）
///    e. 更新召唤物的状态显示
///    f. 设置铜偶的 can_summon 为 false（本回合不能再召唤）
///    g. 更新铜偶的状态显示
/// 6. 如果资源不足：
///    a. 广播资源不足消息到前端（resource_not_enough）
///
/// 使用场景：
/// - 玩家选择召唤位置和敌人类型并确认时
/// - 需要执行召唤逻辑时
///
/// 注意事项：
/// - 召唤会消耗资源，必须确保资源充足
/// - 召唤物是友方单位（owned = true），由玩家控制
/// - 召唤物使用敌人的外观和属性，但属于玩家阵营
/// - 召唤会消耗铜偶的 can_summon 状态，本回合不能再召唤
/// - 如果资源不足，不会创建召唤物，但会通知前端
fn handle_on_summon_apply(
  id : Int,
  position : (Int, Int),
  map : Map_,
  name : String,
) -> Unit {
  let enemy_base = enemy_info_map.get(name).unwrap()
  let resource_cost = enemy_base.summon_cost
  let battle_copper = get_battle_copper_by_id(id)
  if global.val.bag.resources.check_resource_cost(resource_cost) {
    global.val.bag.resources.consume_resource_cost(resource_cost)
    let summoned_enemy = Enemy::new(enemy_base, position, true)
    map.add_occupant(position, Enemy(summoned_enemy))
    set_enemy(summoned_enemy, summoned_enemy.id, position)
    summoned_enemy.update_move_and_attack_and_summon_status()
    battle_copper.can_summon = false
    battle_copper.update_move_and_attack_and_summon_status()
  } else {
    @global_msg.msg_info.broadcast({
      type_msg: "resource_not_enough",
      content: ({ "message": "资源不足" } : Json).stringify(),
    })
  }
}

///|
/// 处理召唤结束或取消事件（清除召唤范围显示）
///
/// 该函数在玩家取消召唤操作或召唤完成后被调用，负责清除所有显示的黄色召唤
/// 范围指示器。函数会遍历所有已设置召唤范围的位置，逐个清除显示，并清空
/// 对应的集合。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置召唤范围的位置（setted_can_summon_blocks）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Summon类型）
/// 4. 清空已设置召唤范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消召唤操作时
/// - 召唤完成后清除范围显示时
/// - 切换操作模式时（如从召唤切换到移动）
///
/// 注意事项：
/// - 函数会清除所有召唤范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
/// - 建筑建造也使用相同的指示器（黄色），所以也会被清除
fn handle_on_summon_end() -> Unit {
  for position in setted_can_summon_blocks {
    clear_block(position)
    check_and_reset_block(position, Summon)
  }
  setted_can_summon_blocks.clear()
}

///|
/// 处理获取召唤菜单事件（返回可召唤的敌人列表）
///
/// 该函数在玩家需要查看可召唤的敌人列表时被调用，负责将全局敌人列表（enemy_list）
/// 序列化为JSON并发送到前端。前端可以使用这个列表显示召唤菜单，让玩家选择要召唤
/// 的敌人类型，并查看每个敌人的资源消耗。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 构造消息对象，包含敌人列表（enemy_list.to_json()）
/// 2. 将消息对象序列化为JSON字符串
/// 3. 通过消息系统广播到前端（msg_info.broadcast）
/// 4. 消息类型为 "get_summon_menu"，前端可以根据此类型显示召唤菜单
///
/// 消息内容：
/// - type_msg: "get_summon_menu"
/// - content: JSON字符串，包含 "contents" 字段，值为敌人列表的JSON数组
///
/// 使用场景：
/// - 玩家点击召唤按钮后需要选择敌人类型时
/// - 需要显示召唤菜单时
///
/// 注意事项：
/// - 返回的是全局敌人列表，包含所有可召唤的敌人类型
/// - 每个敌人信息包含名称、属性、资源消耗等完整数据
/// - 前端需要解析JSON并显示为可选择的菜单
/// - 玩家选择敌人后，需要调用 handle_on_summon_apply 执行召唤
fn handle_on_get_summon_menu() -> Unit {
  msg_info.broadcast({
    type_msg: "get_summon_menu",
    content: ({ "contents": enemy_list.to_json() } : Json).stringify(),
  })
}

// 备注：建筑用的圈和召唤用的圈一样

///|
/// 处理获取建筑建造菜单事件（返回可建造的建筑列表）
///
/// 该函数在玩家需要查看可建造的建筑列表时被调用，负责将全局建筑列表（structure_info_list）
/// 序列化为JSON并发送到前端。前端可以使用这个列表显示建造菜单，让玩家选择要建造的
/// 建筑类型，并查看每个建筑的资源消耗。注意：某些建筑（如充能线圈）会被过滤掉。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 构造消息对象，包含建筑列表（structure_info_list.to_json()）
/// 2. 将消息对象序列化为JSON字符串
/// 3. 通过消息系统广播到前端（msg_info.broadcast）
/// 4. 消息类型为 "get_structure_menu"，前端可以根据此类型显示建造菜单
///
/// 消息内容：
/// - type_msg: "get_structure_menu"
/// - content: JSON字符串，包含 "contents" 字段，值为建筑列表的JSON数组
///
/// 使用场景：
/// - 玩家点击建造按钮后需要选择建筑类型时
/// - 需要显示建造菜单时
///
/// 注意事项：
/// - 返回的是全局建筑列表，包含所有可建造的建筑类型
/// - 每个建筑信息包含名称、属性、资源消耗等完整数据
/// - 前端需要解析JSON并显示为可选择的菜单
/// - 某些建筑（如充能线圈）可能在前端被过滤，不会显示在菜单中
/// - 玩家选择建筑后，需要调用 handle_on_structure_build_apply 执行建造
fn handle_on_get_structure_menu() -> Unit {
  msg_info.broadcast({
    type_msg: "get_structure_menu",
    content: ({ "contents": structure_info_list.to_json() } : Json).stringify(),
  })
}

///|
/// 处理建筑建造开始事件（显示建造范围）
///
/// 该函数在玩家点击建造按钮或开始建造操作时被调用，负责清除其他范围显示、
/// 计算工匠铜偶的可建造位置，并在所有可建造位置显示黄色建造范围指示器。
/// 注意：建造范围指示器与召唤范围指示器使用相同的显示系统（黄色方块）。
///
/// 参数说明：
/// - id: 执行建造的铜偶的唯一ID（必须是工匠类型）
/// - name: 要建造的建筑名称，用于判断是否为矿钻（影响建造位置判断逻辑）
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID获取战斗铜偶实例
/// 3. 获取当前地图实例
/// 4. 计算铜偶的所有可建造位置（get_structure_build_position）
///    - 如果建筑是"心源矿钻"（is_drill = true），需要在矿物上建造
///    - 如果是普通建筑（is_drill = false），需要在空地上建造
/// 5. 遍历所有可建造位置
/// 6. 在每个位置设置黄色建造范围指示器（set_can_summon_blocks，与召唤共用）
/// 7. 将位置添加到已设置召唤范围的集合中（setted_can_summon_blocks，与召唤共用）
///
/// 使用场景：
/// - 玩家点击建造按钮时（工匠铜偶）
/// - 需要显示建造范围时
///
/// 注意事项：
/// - 只有工匠类型的铜偶才能建造，其他类型调用此函数无意义
/// - 函数会清除其他范围显示，确保只显示建造范围
/// - 建造范围指示器与召唤范围指示器共用（都是黄色），使用相同的集合
/// - 矿钻和普通建筑的建造位置判断逻辑不同，需要正确传入 name 参数
/// - 指示器会一直显示直到玩家取消建造或执行建造
fn handle_on_structure_build_start(id : Int, name : String) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let battle_copper = get_battle_copper_by_id(id)
  let map = force_get_current_map()
  let can_build = battle_copper.get_structure_build_position(
    map,
    is_drill=name == "心源矿钻",
  )
  for position in can_build {
    set_can_summon_blocks(position)
    setted_can_summon_blocks.add(position)
  }
}

///|
/// 处理建筑建造实施事件（执行建造并消耗资源）
///
/// 该函数在玩家选择建造位置和建筑类型并确认建造时被调用，负责检查资源是否充足、
/// 消耗资源、处理特殊建筑逻辑（如矿钻需要移除材料）、创建建筑、将建筑添加到地图，
/// 并更新状态。这是建造系统的核心函数。
///
/// 参数说明：
/// - id: 执行建造的铜偶的唯一ID（必须是工匠类型）
/// - position: 建造位置坐标 (x, y)，必须是可建造的位置
/// - map: 当前游戏地图实例，用于添加建筑和查询占用者
/// - name: 要建造的建筑名称，必须存在于 structure_info_map 中
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 根据建筑名称获取建筑基础信息（structure_info_map.get）
/// 2. 获取建造所需的资源消耗（structure_base.cost）
/// 3. 根据ID获取战斗铜偶实例
/// 4. 检查资源是否充足（check_resource_cost）
/// 5. 如果资源充足：
///    a. 消耗资源（consume_resource_cost）
///    b. 处理特殊建筑逻辑：
///       - 如果是"心源矿钻"：获取位置的材料，移除材料，获取材料类型作为建筑资源类型
///       - 如果是普通建筑：资源类型为 None
///    c. 创建建筑实例（Structure::new，owned = true）
///    d. 将建筑添加到地图（map.add_occupant）
///    e. 通知前端显示建筑（set_structure）
///    f. 设置铜偶的 can_build 为 false（本回合不能再建造）
///    g. 更新建筑的状态显示
///    h. 清除建造范围指示器（handle_on_structure_build_end）
/// 6. 如果资源不足：
///    a. 广播资源不足消息到前端（resource_not_enough）
///    b. 清除建造范围指示器（即使建造失败也要清除）
///
/// 使用场景：
/// - 玩家选择建造位置和建筑类型并确认时
/// - 需要执行建造逻辑时
///
/// 注意事项：
/// - 建造会消耗资源，必须确保资源充足
/// - 建筑是玩家拥有的（owned = true），属于玩家阵营
/// - 矿钻建筑需要在矿物上建造，建造时会移除材料并记录资源类型
/// - 建造会消耗铜偶的 can_build 状态，本回合不能再建造
/// - 无论建造成功与否，都会清除建造范围指示器
fn handle_on_structure_build_apply(
  id : Int,
  position : (Int, Int),
  map : Map_,
  name : String,
) -> Unit {
  let structure_base = structure_info_map.get(name).unwrap()
  let resource_cost = structure_base.cost
  let battle_copper = get_battle_copper_by_id(id)
  if global.val.bag.resources.check_resource_cost(resource_cost) {
    global.val.bag.resources.consume_resource_cost(resource_cost)
    let resource_type = if name == "心源矿钻" {
      let material = map.get_occupant(position)
      guard material is Material(material)
      map.remove_occupant(position)
      remove_unit(material.id)
      Some(material.material_base.resource_type)
    } else {
      None
    }
    let structure = Structure::new(
      structure_base,
      owned=true,
      resource_type~,
      position,
    )
    map.add_occupant(position, Structure(structure))
    set_structure(structure, structure.id, position)
    battle_copper.can_build = false
    structure.update_move_and_attack_and_summon_status()
    // 建造成功，清理黄色方块
    handle_on_structure_build_end()
  } else {
    msg_info.broadcast({
      type_msg: "resource_not_enough",
      content: ({ "message": "资源不足" } : Json).stringify(),
    })
    // 建造失败，也要清理黄色方块
    handle_on_structure_build_end()
  }
}

///|
/// 处理建筑建造结束或取消事件（清除建造范围显示）
///
/// 该函数在玩家取消建造操作或建造完成后被调用，负责清除所有显示的黄色建造
/// 范围指示器。函数会遍历所有已设置召唤/建造范围的位置（两者共用同一集合），
/// 逐个清除显示，并清空对应的集合。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置召唤/建造范围的位置（setted_can_summon_blocks，两者共用）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Summon类型，与召唤共用）
/// 4. 清空已设置召唤/建造范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消建造操作时
/// - 建造完成后清除范围显示时
/// - 切换操作模式时（如从建造切换到移动）
///
/// 注意事项：
/// - 函数会清除所有建造范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - 建造范围指示器与召唤范围指示器共用同一集合和显示系统
/// - check_and_reset_block 用于处理地块状态的重置逻辑
fn handle_on_structure_build_end() -> Unit {
  for position in setted_can_summon_blocks {
    clear_block(position)
    check_and_reset_block(position, Summon)
  }
  setted_can_summon_blocks.clear()
}
