///|
/// 处理敌人被点击事件（显示敌人信息和状态）
///
/// 该函数在玩家点击战斗中的敌人时被调用，负责清除所有当前显示的范围指示器、
/// 获取敌人信息、检查是否有可攻击目标，并将信息发送到前端用于渲染信息栏。
/// 注意：这里的敌人可以是野生敌人，也可以是玩家拥有的友方召唤物。
///
/// 参数说明：
/// - id: 被点击的敌人的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有当前显示的范围指示器（移动、攻击、召唤范围）
/// 2. 根据ID从 enemy_map 获取敌人实例
/// 3. 获取当前地图实例
/// 4. 检查敌人是否有可攻击目标（has_attack_targets）
/// 5. 构造消息并广播到前端，包含敌人信息和是否有攻击目标
///
/// 使用场景：
/// - 玩家点击战斗中的敌人时
/// - 需要查看敌人信息时
/// - 需要切换选中的敌人时（友方召唤物）
///
/// 注意事项：
/// - 点击敌人会清除所有范围显示，避免视觉混乱
/// - 消息包含完整的敌人JSON数据，前端可以渲染详细信息
/// - has_attack_targets 用于前端判断是否显示攻击按钮（友方召唤物）
/// - 友方召唤物和野生敌人都可以点击，但行为可能不同
fn handle_on_click_enemy(id : Int) -> Unit {
  // 清除所有范围显示（切换敌人时）
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let enemy = enemy_map.get(id).unwrap()
  let map = force_get_current_map()
  // 检查是否有攻击目标
  let has_attack_targets = !enemy.get_attack_targets(map).is_empty()
  msg_info.broadcast({
    type_msg: "handle_on_click_enemy",
    content: (
      { "enemy": enemy.to_json(), "has_attack_targets": has_attack_targets } :
      Json).stringify(),
  })
}

///|
/// 处理友方召唤物开始攻击事件（显示攻击范围）
///
/// 该函数在玩家控制友方召唤物开始攻击操作时被调用，负责清除其他范围显示、
/// 计算友方召唤物的攻击目标，并在所有可攻击目标的位置显示红色攻击范围指示器。
/// 注意：只有玩家拥有的友方召唤物（owned = true）才会调用此函数，野生敌人由AI控制。
///
/// 参数说明：
/// - map: 当前游戏地图实例，用于查询位置和占用者信息
/// - id: 执行攻击的友方召唤物的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID从 enemy_map 获取敌人实例（必须是友方召唤物）
/// 3. 计算友方召唤物的所有可攻击目标（get_attack_targets）
/// 4. 遍历所有可攻击目标，获取目标位置
/// 5. 在每个目标位置设置红色攻击范围指示器（set_attack_block）
/// 6. 将位置添加到已设置攻击范围的集合中（setted_attack_blocks）
///
/// 使用场景：
/// - 玩家控制友方召唤物点击攻击按钮时
/// - 需要显示友方召唤物攻击范围时
///
/// 注意事项：
/// - 只有友方召唤物（owned = true）才会调用此函数
/// - 函数会清除其他范围显示，确保只显示攻击范围
/// - 攻击范围指示器是红色的，用于区分移动范围（绿色）和召唤范围（黄色）
/// - 只有可攻击的目标位置会显示指示器
/// - 指示器会一直显示直到玩家取消攻击或执行攻击
fn handle_on_enemy_attack_start(map : Map_, id : Int) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let enemy = enemy_map.get(id).unwrap()
  let attack_target = enemy.get_attack_targets(map)
  for target in attack_target {
    let position = target.get_position_from_can_attack_target()
    set_attack_block(position)
    setted_attack_blocks.add(position)
  }
}

///|
/// 处理友方召唤物攻击结束或取消事件（清除攻击范围显示）
///
/// 该函数在玩家取消友方召唤物的攻击操作或攻击完成后被调用，负责清除所有显示的
/// 红色攻击范围指示器。函数会遍历所有已设置攻击范围的位置，逐个清除显示，并清空
/// 对应的集合。注意：此函数与铜偶的攻击结束函数功能相同，共用同一套攻击范围显示系统。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置攻击范围的位置（setted_attack_blocks，与铜偶共用）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Attack类型）
/// 4. 清空已设置攻击范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消友方召唤物的攻击操作时
/// - 友方召唤物攻击完成后清除范围显示时
/// - 切换操作模式时（如从攻击切换到移动）
///
/// 注意事项：
/// - 函数会清除所有攻击范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
/// - 与铜偶的攻击范围显示共用同一集合，清除会影响所有攻击范围显示
fn handle_on_enemy_attack_end() -> Unit {
  for position in setted_attack_blocks {
    clear_block(position)
    check_and_reset_block(position, Attack)
  }
  setted_attack_blocks.clear()
}

///|
/// 处理友方召唤物攻击实施事件（执行攻击并计算伤害）
///
/// 该函数在玩家选择攻击目标并确认攻击时被调用，负责执行完整的攻击流程：
/// 触发摄像机动画、获取目标、根据目标类型执行不同的攻击逻辑、处理击杀、
/// 更新状态，并清除攻击范围显示。这是友方召唤物攻击系统的核心函数。
///
/// 参数说明：
/// - id: 执行攻击的友方召唤物的唯一ID
/// - position: 攻击目标的位置坐标 (x, y)
/// - map: 当前游戏地图实例，用于查询目标信息
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 触发摄像机动画，聚焦到攻击的友方召唤物（animate_move）
/// 2. 根据ID从 enemy_map 获取敌人实例（必须是友方召唤物）
/// 3. 从地图获取目标位置的占用者（get_occupant）
/// 4. 根据目标类型执行不同的攻击逻辑：
///    a. Enemy（敌方敌人）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：添加掉落物品到背包、移除敌人、通知前端移除单位
///       - 如果未击杀：更新敌人生命值显示
///       - 检查BOSS击杀条件（饕餮、夏特拉），如果都击杀则游戏胜利
///    b. Structure（敌方建筑）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：移除建筑、通知前端移除单位
///       - 如果未击杀：更新建筑生命值显示
/// 5. 设置友方召唤物的 can_attack 为 false（本回合不能再攻击）
/// 6. 更新友方召唤物的状态显示
/// 7. 清除所有攻击范围指示器
/// 8. 如果攻击成功（目标不是空），发送攻击完成消息（attack_complete）
///
/// 使用场景：
/// - 玩家选择攻击目标并确认时（友方召唤物）
/// - 需要执行友方召唤物攻击逻辑时
///
/// 注意事项：
/// - 攻击会消耗友方召唤物的 can_attack 状态，本回合不能再攻击
/// - 击杀敌人会获得掉落物品，自动添加到背包
/// - BOSS击杀有特殊逻辑，需要两个BOSS都击杀才能胜利
/// - 友方召唤物不能攻击玩家铜偶，只能攻击敌方单位
/// - 无论攻击成功与否，都会清除攻击范围显示
fn handle_on_enemy_attack_apply(
  id : Int,
  position : (Int, Int),
  map : Map_,
) -> Unit {
  // 攻击前将视角聚焦到敌人
  animate_move(id)
  let enemy = enemy_map.get(id).unwrap()
  let target = map.get_occupant(position)
  match target {
    Enemy(target_enemy) => {
      let result = target_enemy.apply_attack(enemy.enemy_base.attack)
      // 单位被击杀
      if result {
        global.val.bag.add_resource(target_enemy.get_drop_items())
        enemy_map.remove(target_enemy.id)
        remove_unit(target_enemy.id)
        map.remove_occupant(target_enemy.position)
        if boss_borned.val == true {
          if target_enemy.enemy_base.name == "（BOSS）废械吞噬者·饕餮" {
            taotle_killed.val = true
          } else if target_enemy.enemy_base.name ==
            "（BOSS）织网夫人·夏特拉" {
            xtale_killed.val = true
          }
          if taotle_killed.val == true && xtale_killed.val == true {
            success()
          }
        }
      } else {
        // 更新敌人血量显示
        update_health(
          target_enemy.id,
          target_enemy.now_health,
          target_enemy.enemy_base.health,
        )
      }
      enemy.can_attack = false
      enemy.update_move_and_attack_and_summon_status()
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
      enemy.can_attack = false
      enemy.update_move_and_attack_and_summon_status()
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
/// 处理友方召唤物移动开始事件（显示移动范围）
///
/// 该函数在玩家控制友方召唤物开始移动操作时被调用，负责清除其他范围显示、
/// 计算友方召唤物的可移动位置，并在所有可移动位置显示绿色移动范围指示器。
/// 注意：只有玩家拥有的友方召唤物（owned = true）才会调用此函数，野生敌人由AI控制。
///
/// 参数说明：
/// - map: 当前游戏地图实例，用于查询位置和占用情况
/// - id: 执行移动的友方召唤物的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID从 enemy_map 获取敌人实例（必须是友方召唤物）
/// 3. 计算友方召唤物的所有可移动位置（get_can_move）
/// 4. 遍历所有可移动位置
/// 5. 在每个位置设置绿色移动范围指示器（set_move_block）
/// 6. 将位置添加到已设置移动范围的集合中（setted_move_blocks，与铜偶共用）
///
/// 使用场景：
/// - 玩家控制友方召唤物点击移动按钮时
/// - 需要显示友方召唤物移动范围时
///
/// 注意事项：
/// - 只有友方召唤物（owned = true）才会调用此函数
/// - 函数会清除其他范围显示，确保只显示移动范围
/// - 移动范围指示器是绿色的，用于区分攻击范围（红色）和召唤范围（黄色）
/// - 只有可移动的位置会显示指示器（考虑占用、边界等）
/// - 指示器会一直显示直到玩家取消移动或执行移动
fn handle_on_enemy_move_start(map : Map_, id : Int) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let enemy = enemy_map.get(id).unwrap()
  let can_move = enemy.get_can_move(map)
  for position in can_move {
    set_move_block(position)
    setted_move_blocks.add(position)
  }
}

///|
/// 处理友方召唤物移动结束或取消事件（清除移动范围显示）
///
/// 该函数在玩家取消友方召唤物的移动操作或移动完成后被调用，负责清除所有显示的
/// 绿色移动范围指示器。函数会遍历所有已设置移动范围的位置，逐个清除显示，并清空
/// 对应的集合。注意：此函数与铜偶的移动结束函数功能相同，共用同一套移动范围显示系统。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置移动范围的位置（setted_move_blocks，与铜偶共用）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Move类型）
/// 4. 清空已设置移动范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消友方召唤物的移动操作时
/// - 友方召唤物移动完成后清除范围显示时
/// - 切换操作模式时（如从移动切换到攻击）
///
/// 注意事项：
/// - 函数会清除所有移动范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
/// - 与铜偶的移动范围显示共用同一集合，清除会影响所有移动范围显示
fn handle_on_enemy_move_end() -> Unit {
  for position in setted_move_blocks {
    clear_block(position)
    check_and_reset_block(position, Move)
  }
  setted_move_blocks.clear()
}

///|
/// 处理友方召唤物移动实施事件（执行移动，不允许出界）
///
/// 该函数在玩家选择移动目标并确认移动时被调用，负责执行完整的移动流程：
/// 触发摄像机动画、处理房间内移动、更新友方召唤物位置和朝向、更新状态，并清除
/// 移动范围显示。注意：与铜偶移动不同，友方召唤物不允许移动到地图边界外，如果
/// 尝试移动到未生成的房间会导致程序终止。
///
/// 参数说明：
/// - id: 执行移动的友方召唤物的唯一ID
/// - position: 目标移动位置坐标 (x, y)，必须在已有房间内
/// - map: 当前游戏地图实例，用于查询位置和房间信息
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 触发摄像机动画，聚焦到移动的友方召唤物（animate_move）
/// 2. 根据ID从 enemy_map 获取敌人实例（必须是友方召唤物）
/// 3. 检查目标位置是否在当前已有的房间内（find_position_in_map）
/// 4. 如果位置在已有房间内：
///    a. 获取当前位置和房间信息（global_position_to_room_position）
///    b. 获取目标位置和房间信息
///    c. 从旧房间位置移除友方召唤物（设置为Empty）
///    d. 将友方召唤物添加到新房间位置（设置为Enemy）
///    e. 更新友方召唤物的全局位置
///    f. 根据移动方向改变友方召唤物朝向（change_direction）
///    g. 通知前端执行移动动画（move_to）
/// 5. 如果位置不在已有房间内：
///    a. 触发程序终止（abort），因为友方召唤物不允许出界
/// 6. 设置友方召唤物的 can_move 为 false（本回合不能再移动）
/// 7. 更新友方召唤物的状态显示
/// 8. 清除所有移动范围指示器
///
/// 使用场景：
/// - 玩家选择移动目标并确认时（友方召唤物）
/// - 需要执行友方召唤物移动逻辑时
///
/// 注意事项：
/// - 移动会消耗友方召唤物的 can_move 状态，本回合不能再移动
/// - 友方召唤物不允许移动到地图边界外，尝试出界会导致程序崩溃
/// - 与铜偶不同，友方召唤物不会触发新房间生成
/// - 友方召唤物移动后会更新朝向，面向移动方向
/// - 如果目标位置不在已有房间内，会立即终止程序
fn handle_on_enemy_move_apply(
  id : Int,
  position : (Int, Int),
  map : Map_,
) -> Unit {
  // 移动前将视角聚焦到敌人
  animate_move(id)
  let enemy = enemy_map.get(id).unwrap()
  if map.find_position_in_map(position) is Some(_) {
    // 如果仍在当前已有的房间内  
    // 移除旧位置的敌人，并将其放到新位置
    let now_position = enemy.position
    // 将全局坐标转换为房间本地坐标
    let (now_room, now_local_pos) = map
      .global_position_to_room_position(now_position)
      .unwrap()
    let (target_room, target_local_pos) = map
      .global_position_to_room_position(position)
      .unwrap()
    now_room.blocks[now_local_pos.0][now_local_pos.1].occupant = Empty
    target_room.blocks[target_local_pos.0][target_local_pos.1].occupant = Occupant::Enemy(
      enemy,
    )
    // 更新敌人的位置
    enemy.position = position
    // 根据位置改变敌人的朝向
    change_direction(
      id,
      convert_direction_to_unit_direction(
        get_direction_by_position(now_position, position),
      ),
    )
    // 移动敌人到新位置
    move_to(id, position)
  } else {
    abort("enemy move to out of map")
  }
  enemy.can_move = false
  enemy.update_move_and_attack_and_summon_status()
  for position in setted_move_blocks {
    clear_block(position)
    check_and_reset_block(position, Move)
  }
  setted_move_blocks.clear()
}
