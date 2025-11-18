///|
/// 已设置攻击范围指示器的位置集合（全局状态）
///
/// 该集合存储所有当前显示红色攻击范围指示器的位置坐标。当玩家点击攻击按钮时，
/// 可攻击目标的位置会被添加到此集合；当攻击结束或取消时，集合会被清空。
/// 注意：此集合与铜偶、友方召唤物、建筑的攻击范围显示共用。
let setted_attack_blocks : Set[(Int, Int)] = Set::new()

///|
/// 已设置移动范围指示器的位置集合（全局状态）
///
/// 该集合存储所有当前显示绿色移动范围指示器的位置坐标。当玩家点击移动按钮时，
/// 可移动位置会被添加到此集合；当移动结束或取消时，集合会被清空。
/// 注意：此集合与铜偶、友方召唤物的移动范围显示共用。
let setted_move_blocks : Set[(Int, Int)] = Set::new()

///|
/// 已设置传送范围指示器的位置集合（全局状态）
///
/// 该集合存储所有当前显示传送范围指示器的位置坐标。用于某些特殊功能（如传送门等），
/// 目前可能未完全使用。当传送操作结束或取消时，集合会被清空。
let setted_transfer_blocks : Set[(Int, Int)] = Set::new()

///|
/// 已设置召唤/建造范围指示器的位置集合（全局状态）
///
/// 该集合存储所有当前显示黄色召唤或建造范围指示器的位置坐标。当玩家点击召唤或建造
/// 按钮时，可召唤/建造位置会被添加到此集合；当操作结束或取消时，集合会被清空。
/// 注意：召唤范围和建造范围共用此集合和显示系统（都是黄色指示器）。
let setted_can_summon_blocks : Set[(Int, Int)] = Set::new()

///|
/// 忽略地块类型枚举（用于地块状态重置）
///
/// 该枚举定义了在清除地块状态指示器时需要忽略的类型。当清除某种类型的指示器时，
/// 需要检查该位置是否还有其他类型的指示器，如果有则恢复显示。
///
/// 枚举值：
/// - Attack: 攻击范围指示器（红色）
/// - Move: 移动范围指示器（绿色）
/// - Summon: 召唤/建造范围指示器（黄色）
priv enum IgnoreBlock {
  Attack
  Move
  Summon
}

///|
/// 检查并重置地块状态（恢复被覆盖的其他类型指示器）
///
/// 该函数用于在清除某种类型的地块状态指示器时，检查该位置是否还有其他类型的
/// 指示器，如果有则恢复显示。这是因为不同类型的指示器可能重叠在同一位置，
/// 清除一种类型时不应该影响其他类型的显示。
///
/// 参数说明：
/// - position: 需要检查并重置的地块位置坐标 (x, y)
/// - ignore_block: 当前正在清除的指示器类型，此类型不会被恢复
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 重置逻辑（根据忽略类型）：
/// 1. 如果忽略 Attack（正在清除攻击范围）:
///    - 检查位置是否在移动范围集合中，如果是则恢复显示移动范围（绿色）
///    - 检查位置是否在传送范围集合中，如果是则恢复显示传送范围
///    - 检查位置是否在召唤范围集合中，如果是则恢复显示召唤范围（黄色）
///
/// 2. 如果忽略 Move（正在清除移动范围）:
///    - 检查位置是否在攻击范围集合中，如果是则恢复显示攻击范围（红色）
///    - 检查位置是否在传送范围集合中，如果是则恢复显示传送范围
///    - 检查位置是否在召唤范围集合中，如果是则恢复显示召唤范围（黄色）
///
/// 3. 如果忽略 Summon（正在清除召唤/建造范围）:
///    - 检查位置是否在攻击范围集合中，如果是则恢复显示攻击范围（红色）
///    - 检查位置是否在传送范围集合中，如果是则恢复显示传送范围
///    - 检查位置是否在移动范围集合中，如果是则恢复显示移动范围（绿色）
///
/// 使用场景：
/// - 清除攻击范围时，恢复可能被覆盖的移动范围或召唤范围
/// - 清除移动范围时，恢复可能被覆盖的攻击范围或召唤范围
/// - 清除召唤范围时，恢复可能被覆盖的攻击范围或移动范围
///
/// 注意事项：
/// - 函数只恢复其他类型的指示器，不会恢复被忽略的类型
/// - 确保在清除指示器后调用此函数，避免状态不一致
/// - 不同类型的指示器可能重叠，需要正确处理优先级
fn check_and_reset_block(
  position : (Int, Int),
  ignore_block : IgnoreBlock,
) -> Unit {
  // 清除攻击块时，检查是否需要恢复移动块或转移块
  if ignore_block is Attack {
    if setted_move_blocks.contains(position) {
      set_move_block(position)
    } else if setted_transfer_blocks.contains(position) {
      set_attack_block(position)
    } else if setted_can_summon_blocks.contains(position) {
      set_can_summon_blocks(position)
    }
  }
  // 清除移动块时，检查是否需要恢复攻击块或转移块
  if ignore_block is Move {
    if setted_attack_blocks.contains(position) {
      set_attack_block(position)
    } else if setted_transfer_blocks.contains(position) {
      set_attack_block(position)
    } else if setted_can_summon_blocks.contains(position) {
      set_can_summon_blocks(position)
    }
  }
  if ignore_block is Summon {
    if setted_attack_blocks.contains(position) {
      set_attack_block(position)
    } else if setted_transfer_blocks.contains(position) {
      set_attack_block(position)
    } else if setted_move_blocks.contains(position) {
      set_move_block(position)
    }
  }
}
