///|
/// 可攻击目标的抽象
priv enum CanAttackTarget {
  Enemy(Enemy)
  Copper(BattleCopper)
  Structure(Structure)
}

///|
/// 从可攻击目标枚举中提取目标的位置坐标
///
/// 该函数用于从 CanAttackTarget 枚举中提取目标的位置信息。CanAttackTarget 是
/// 一个联合类型，可以包含三种不同类型的目标：Enemy（敌人）、Copper（铜偶）、
/// Structure（建筑）。函数会根据目标的类型，从对应的结构体中提取位置坐标。
///
/// 参数说明：
/// - can_attack_target: 可攻击目标枚举值，可以是 Enemy、Copper 或 Structure
///
/// 返回值：
/// - 返回 (Int, Int) 元组，表示目标在地图上的位置坐标 (x, y)
///
/// 提取逻辑：
/// - 如果目标是 Enemy（敌人），返回 enemy.position
/// - 如果目标是 Copper（铜偶），返回 copper.position
/// - 如果目标是 Structure（建筑），返回 structure.position
///
/// 使用场景：
/// - 需要获取攻击目标的位置时
/// - 计算到目标的距离时
/// - 显示攻击范围时
/// - 需要统一处理不同类型目标的位置时
///
/// 注意事项：
/// - 函数可以处理所有三种目标类型
/// - 返回的位置是目标当前在地图上的坐标
/// - 如果目标移动了位置，需要重新调用此函数获取最新位置
fn CanAttackTarget::get_position_from_can_attack_target(
  can_attack_target : CanAttackTarget,
) -> (Int, Int) {
  match can_attack_target {
    Enemy(enemy) => enemy.position
    Copper(copper) => copper.position
    Structure(structure) => structure.position
  }
}
