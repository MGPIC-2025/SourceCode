///|
/// 处理建筑被点击事件（显示建筑信息）
///
/// 该函数在玩家点击战斗中的建筑时被调用，负责获取建筑信息并将信息发送到前端
/// 用于渲染信息栏。建筑可以是玩家拥有的建筑（如防御塔、矿钻等），也可以是敌方建筑。
///
/// 参数说明：
/// - id: 被点击的建筑的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 根据ID获取建筑实例（get_structure_by_id）
/// 2. 构造消息并广播到前端，包含建筑的完整JSON数据
/// 3. 消息类型为 "handle_on_click_structure"，前端可以根据此类型显示建筑信息
///
/// 使用场景：
/// - 玩家点击战斗中的建筑时
/// - 需要查看建筑信息时
///
/// 注意事项：
/// - 消息包含完整的建筑JSON数据，前端可以渲染详细信息
/// - 建筑信息包括名称、属性、资源类型（如果是矿钻）、生命值等
/// - 点击建筑不会清除范围显示，与点击铜偶/敌人不同
fn handle_on_click_structure(id : Int) -> Unit {
  let structure = get_structure_by_id(id)
  msg_info.broadcast({
    type_msg: "handle_on_click_structure",
    content: ({ "structure": structure.to_json() } : Json).stringify(),
  })
}

///|
/// 处理建筑开始攻击事件（显示攻击范围）
///
/// 该函数在玩家点击建筑攻击按钮或开始攻击操作时被调用，负责清除其他范围显示、
/// 计算建筑的攻击目标，并在所有可攻击目标的位置显示红色攻击范围指示器。
/// 注意：只有有攻击能力的建筑（如防御塔）才会调用此函数。
///
/// 参数说明：
/// - map: 当前游戏地图实例，用于查询位置和占用者信息
/// - id: 执行攻击的建筑的唯一ID
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除所有其他范围显示（移动、攻击、召唤范围），避免视觉冲突
/// 2. 根据ID获取建筑实例（get_structure_by_id）
/// 3. 计算建筑的所有可攻击目标（get_attack_targets）
/// 4. 遍历所有可攻击目标，获取目标位置
/// 5. 在每个目标位置设置红色攻击范围指示器（set_attack_block）
/// 6. 将位置添加到已设置攻击范围的集合中（setted_attack_blocks，与铜偶共用）
///
/// 使用场景：
/// - 玩家点击建筑攻击按钮时（有攻击能力的建筑）
/// - 需要显示建筑攻击范围时
///
/// 注意事项：
/// - 只有有攻击能力的建筑（structure_base.can_attack = true）才会调用此函数
/// - 函数会清除其他范围显示，确保只显示攻击范围
/// - 攻击范围指示器是红色的，用于区分移动范围（绿色）和召唤范围（黄色）
/// - 只有可攻击的目标位置会显示指示器
/// - 指示器会一直显示直到玩家取消攻击或执行攻击
fn handle_on_structure_attack_start(map : Map_, id : Int) -> Unit {
  handle_on_move_end()
  handle_on_attack_end()
  handle_on_summon_end()
  let structure = get_structure_by_id(id)
  let attack_target = structure.get_attack_targets(map)
  for target in attack_target {
    let position = target.get_position_from_can_attack_target()
    set_attack_block(position)
    setted_attack_blocks.add(position)
  }
}

///|
/// 处理建筑攻击结束或取消事件（清除攻击范围显示）
///
/// 该函数在玩家取消建筑的攻击操作或攻击完成后被调用，负责清除所有显示的红色
/// 攻击范围指示器。函数会遍历所有已设置攻击范围的位置，逐个清除显示，并清空
/// 对应的集合。注意：此函数与铜偶和友方召唤物的攻击结束函数功能相同，共用同一套攻击范围显示系统。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 遍历所有已设置攻击范围的位置（setted_attack_blocks，与其他单位共用）
/// 2. 对每个位置调用 clear_block() 清除前端显示
/// 3. 调用 check_and_reset_block() 检查并重置地块状态（Attack类型）
/// 4. 清空已设置攻击范围的集合，准备下次使用
///
/// 使用场景：
/// - 玩家取消建筑的攻击操作时
/// - 建筑攻击完成后清除范围显示时
/// - 切换操作模式时
///
/// 注意事项：
/// - 函数会清除所有攻击范围指示器，确保视觉上完全清理
/// - 清除后集合会被清空，不会保留任何状态
/// - check_and_reset_block 用于处理地块状态的重置逻辑
/// - 与其他单位的攻击范围显示共用同一集合，清除会影响所有攻击范围显示
fn handle_on_structure_attack_end() -> Unit {
  for position in setted_attack_blocks {
    clear_block(position)
    check_and_reset_block(position, Attack)
  }
  setted_attack_blocks.clear()
}

///|
/// 处理建筑攻击实施事件（执行攻击并计算伤害）
///
/// 该函数在玩家选择攻击目标并确认攻击时被调用，负责执行完整的攻击流程：
/// 触发摄像机动画、获取目标、根据目标类型和建筑归属执行不同的攻击逻辑、
/// 处理击杀、更新状态，并清除攻击范围显示。这是建筑攻击系统的核心函数。
/// 注意：玩家建筑攻击铜偶时是治疗效果，攻击敌方单位时是伤害。
///
/// 参数说明：
/// - id: 执行攻击的建筑的唯一ID
/// - position: 攻击目标的位置坐标 (x, y)
/// - map: 当前游戏地图实例，用于查询目标信息
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 触发摄像机动画，聚焦到攻击的建筑（animate_move）
/// 2. 根据ID获取建筑实例（get_structure_by_id）
/// 3. 从地图获取目标位置的占用者（get_occupant）
/// 4. 根据目标类型执行不同的攻击逻辑：
///    a. Enemy（敌人）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：添加掉落物品到背包、移除敌人、通知前端移除单位
///       - 如果未击杀：更新敌人生命值显示
///    b. Copper（玩家铜偶）:
///       - 如果建筑是玩家拥有的（owned = true）：应用治疗效果（apply_mechanic_heal）
///       - 如果建筑是敌方的（owned = false）：应用攻击伤害（apply_attack）
///       - 如果击杀铜偶：移除铜偶，如果所有铜偶被击败则游戏结束
///       - 更新铜偶生命值显示
///    c. Structure（其他建筑）:
///       - 应用攻击伤害（apply_attack）
///       - 如果击杀：移除建筑、通知前端移除单位
///       - 如果未击杀：更新建筑生命值显示
/// 5. 设置建筑的 can_attack 为 false（本回合不能再攻击）
/// 6. 更新建筑的状态显示
/// 7. 清除所有攻击范围指示器
/// 8. 如果攻击成功（目标不是空），发送攻击完成消息（attack_complete）
///
/// 使用场景：
/// - 玩家选择攻击目标并确认时（建筑）
/// - 需要执行建筑攻击逻辑时
///
/// 注意事项：
/// - 攻击会消耗建筑的 can_attack 状态，本回合不能再攻击
/// - 玩家建筑攻击玩家铜偶是治疗效果，不是伤害（如维修工坊）
/// - 敌方建筑攻击玩家铜偶是伤害，可能造成击杀
/// - 击杀敌人会获得掉落物品，自动添加到背包
/// - 如果所有玩家铜偶被击败，会触发游戏结束
/// - 无论攻击成功与否，都会清除攻击范围显示
fn handle_on_structure_attack_apply(
  id : Int,
  position : (Int, Int),
  map : Map_,
) -> Unit {
  // 攻击前将视角聚焦到建筑
  animate_move(id)
  let structure = get_structure_by_id(id)
  let target = map.get_occupant(position)
  match target {
    Enemy(enemy) => {
      let result = enemy.apply_attack(structure.structure_base.attribute.attack)
      if result {
        global.val.bag.add_resource(enemy.get_drop_items())
        enemy_map.remove(enemy.id)
        remove_unit(enemy.id)
        map.remove_occupant(enemy.position)
      } else {
        // 更新敌人血量显示
        update_health(enemy.id, enemy.now_health, enemy.enemy_base.health)
      }
      structure.can_attack = false
      structure.update_move_and_attack_and_summon_status()
    }
    Copper(copper) => {
      if structure.owned {
        copper.apply_mechanic_heal(structure.structure_base.attribute.attack)
      } else {
        let result = copper.apply_attack(
          structure.structure_base.attribute.attack,
        )
        if result {
          battle_copper_map.remove(copper.id)
          remove_unit(copper.id)
          map.remove_occupant(copper.position)
        }
        if battle_copper_map.length() == 0 {
          game_over()
        }
      }
      // 更新铜偶血量显示
      update_health(
        copper.id,
        copper.now_health,
        copper.copper.attribute.health,
      )
      structure.can_attack = false
      structure.update_move_and_attack_and_summon_status()
    }
    Structure(structure_) => {
      let result = structure_.apply_attack(
        structure.structure_base.attribute.attack,
      )
      if result {
        structure_map.remove(structure_.id)
        remove_unit(structure_.id)
        map.remove_occupant(structure_.position)
      } else {
        // 更新建筑血量显示
        update_health(
          structure_.id,
          structure_.now_health,
          structure_.structure_base.health,
        )
      }
      structure.can_attack = false
      structure.update_move_and_attack_and_summon_status()
    }
    Empty => ()
    _ => abort("target is not enemy or copper")
  }
  for position in setted_attack_blocks {
    clear_block(position)
    check_and_reset_block(position, Attack)
  }
  setted_attack_blocks.clear()
  if !(target is Empty) {
    attack_complete(id)
  }
}
