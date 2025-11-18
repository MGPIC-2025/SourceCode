///|
let enemy_map : Map[Int, Enemy] = {}

///|
/// 敌人实体
priv struct Enemy {
  id : Int
  owned : Bool // true=友方召唤物，false=野生敌人
  // 是否可以移动/攻击（仅用于 owned 为 true 的敌人）
  mut can_move : Bool
  mut can_attack : Bool
  mut position : (Int, Int)
  mut now_health : Float
  enemy_base : EnemyBase
} derive(ToJson)

///|
/// 敌人基础信息
priv struct EnemyBase {
  level : Int
  health : Float
  attack : Float
  defense : Float
  dodge : Float
  attack_range : Int
  speed : Int
  name : String
  enemy_type : String
  description : String
  asset_url : String
  model_url : String
  drop_items : Array[(ResourceType, (Int, Int))]
  summon_cost : ResourceCost
} derive(ToJson)

///|
/// 创建敌人实体
/// 
/// 该函数用于在游戏中创建一个新的敌人实例。根据敌人是否为玩家召唤物，
/// 会设置不同的初始状态。友方召唤物在第一回合不能移动和攻击，而野生敌人
/// 则可以在创建后立即行动。
///
/// 参数说明：
/// - enemy_base: 敌人的基础信息，包含等级、生命值、攻击力、防御力等属性
/// - position: 敌人在地图上的初始位置坐标 (x, y)
/// - owned: 是否为玩家拥有的召唤物，true表示友方召唤物，false表示野生敌人
///
/// 返回值：
/// - 返回创建的 Enemy 结构体实例，该实例已自动添加到全局 enemy_map 中
///
/// 使用场景：
/// - 游戏开始时生成野生敌人
/// - 玩家使用召唤功能创建友方召唤物
/// - 关卡中动态生成敌人
///
/// 注意事项：
/// - 函数会自动为敌人分配唯一ID
/// - 友方召唤物的 can_move 和 can_attack 初始值为 false，需要在回合开始时更新
/// - 敌人的初始生命值设置为 enemy_base.health
fn Enemy::new(
  enemy_base : EnemyBase,
  position : (Int, Int),
  owned : Bool,
) -> Enemy {
  // 友方召唤物第一回合不能移动和攻击，野生敌人可以
  let can_move = if owned { false } else { true }
  let can_attack = if owned { false } else { true }
  let enemy = {
    id: @id.id_pool.get_id(),
    position,
    owned,
    can_move,
    can_attack,
    now_health: enemy_base.health,
    enemy_base,
  }
  enemy_map.set(enemy.id, enemy)
  enemy
}

///|
/// 获取敌人被击败后掉落的物品列表
///
/// 该函数根据敌人的配置信息，随机生成掉落物品。每个敌人可以配置多个
/// 掉落物品类型，每个物品类型都有最小和最大掉落数量范围。函数会为每个
/// 配置的掉落物品类型生成一个随机数量（在指定范围内）的物品实例。
///
/// 参数说明：
/// - enemy: 被击败的敌人实例，需要从中获取 enemy_base.drop_items 配置
///
/// 返回值：
/// - 返回一个 Item 数组，包含所有随机生成的掉落物品
///
/// 使用场景：
/// - 敌人被击败时调用，用于生成战利品
/// - 资源结算时，将掉落物品添加到玩家背包
///
/// 注意事项：
/// - 掉落数量是随机的，在配置的最小值和最大值之间
/// - 如果配置的掉落数量为 (0, 0)，则不会生成该物品
/// - 所有掉落物品都是 Resource 类型的 Item
fn Enemy::get_drop_items(enemy : Enemy) -> Array[Item] {
  let items = []
  for drop_item in enemy.enemy_base.drop_items {
    let count = summon_random_number(drop_item.1.0, drop_item.1.1)
    items.push(Item::new(Resource(drop_item.0), count~))
  }
  items
}

///|
/// 处理敌人受到攻击的伤害结算逻辑
///
/// 该函数实现了完整的攻击结算流程：首先检查敌人是否成功闪避攻击，
/// 如果闪避成功则不受伤害；如果未闪避，则根据攻击力和防御力计算
/// 实际伤害值，并扣除敌人的生命值。最后返回敌人是否被击杀。
///
/// 参数说明：
/// - enemy: 受到攻击的敌人实例（可变引用）
/// - attack: 攻击者的攻击力数值
///
/// 返回值：
/// - 返回 Bool 类型，true 表示敌人被击杀（生命值 <= 0），false 表示敌人存活
///
/// 伤害计算公式：
/// - 首先计算闪避概率：enemy.enemy_base.dodge / 100
/// - 如果闪避成功，直接返回 false（未击杀）
/// - 如果未闪避，使用 calculate_damage(attack, defense) 计算实际伤害
/// - 实际伤害 = 攻击力 * (攻击力 / (攻击力 + 防御力 * K))
///
/// 使用场景：
/// - 铜偶攻击敌人时
/// - 建筑攻击敌人时
/// - 其他敌人攻击该敌人时（友方召唤物互殴等）
///
/// 注意事项：
/// - 函数会直接修改 enemy.now_health 的值
/// - 闪避判定使用概率检查，可能受到随机数影响
/// - 伤害计算考虑了防御力的减伤效果
fn Enemy::apply_attack(enemy : Enemy, attack : Float) -> Bool {
  if check_probability(enemy.enemy_base.dodge.to_double() / 100) {
    return false
  }
  let damage = calculate_damage(attack, enemy.enemy_base.defense)
  enemy.now_health -= damage
  enemy.now_health <= 0
}

///|
/// 获取敌人在当前攻击范围内可以攻击的所有目标列表
///
/// 该函数根据敌人的攻击范围（attack_range），计算敌人周围所有可攻击的位置，
/// 并检查这些位置上是否有可攻击的目标。根据敌人是否为玩家召唤物，攻击目标
/// 的判断逻辑不同：友方召唤物只能攻击敌方单位，野生敌人只能攻击玩家单位。
///
/// 参数说明：
/// - enemy: 需要获取攻击目标的敌人实例
/// - map: 当前游戏地图实例，用于查询位置占用情况和获取占用者信息
///
/// 返回值：
/// - 返回 CanAttackTarget 数组，包含所有在攻击范围内的可攻击目标
/// - 可能的目标类型包括：Enemy（敌方敌人）、Copper（玩家铜偶）、Structure（玩家建筑）
///
/// 攻击范围计算：
/// - 使用 generate_offset(attack_range) 生成所有在攻击范围内的位置偏移
/// - 对于每个偏移位置，计算实际坐标 = enemy.position + offset
/// - 检查该位置是否被占用，如果占用则进一步判断占用者类型
///
/// 目标判断逻辑：
/// - 友方召唤物（owned = true）：只能攻击敌方敌人和敌方建筑
/// - 野生敌人（owned = false）：只能攻击玩家铜偶、友方召唤物和玩家建筑
///
/// 使用场景：
/// - 显示敌人可攻击范围时
/// - 敌人AI选择攻击目标时
/// - 玩家查看敌人攻击能力时
///
/// 注意事项：
/// - 攻击范围是正方形范围，不是圆形范围
/// - 函数只返回在攻击范围内的目标，不考虑路径阻挡
/// - 空数组表示当前没有可攻击目标
fn Enemy::get_attack_targets(
  enemy : Enemy,
  map : Map_,
) -> Array[CanAttackTarget] {
  let attack_range = enemy.enemy_base.attack_range
  let offset = generate_offset(attack_range)
  let can_attack = []
  for offset_ in offset {
    let position = (enemy.position.0 + offset_.0, enemy.position.1 + offset_.1)
    if map.is_occupy(position) {
      let occupant = map.get_occupant(position)
      if enemy.owned {
        match occupant {
          Enemy(enemy) if enemy.owned == false =>
            can_attack.push(CanAttackTarget::Enemy(enemy))
          Structure(structure) if structure.owned == false =>
            can_attack.push(CanAttackTarget::Structure(structure))
          _ => ()
        }
      } else {
        match occupant {
          Copper(copper) => can_attack.push(CanAttackTarget::Copper(copper))
          Enemy(enemy) if enemy.owned == true =>
            can_attack.push(CanAttackTarget::Enemy(enemy))
          Structure(structure) if structure.owned == true =>
            can_attack.push(CanAttackTarget::Structure(structure))
          _ => ()
        }
      }
    }
  }
  can_attack
}

///|
/// 查找距离敌人最近的攻击目标（用于AI自动攻击）
///
/// 该函数用于敌人AI系统，帮助敌人自动选择最近的攻击目标。函数会遍历所有
/// 可能的攻击目标（包括玩家铜偶、友方召唤物、玩家建筑），计算每个目标与
/// 敌人的曼哈顿距离，然后返回距离最近的目标。
///
/// 参数说明：
/// - enemy: 需要查找攻击目标的敌人实例
///
/// 返回值：
/// - 返回 CanAttackTarget? 类型，Some(target) 表示找到最近目标，None 表示没有可攻击目标
///
/// 目标搜索范围：
/// - 所有战斗中的玩家铜偶（通过 get_battle_copper_list() 获取）
/// - 所有友方召唤物（enemy_map 中 owned = true 的其他敌人）
/// - 所有玩家拥有的建筑（structure_map 中 owned = true 的建筑）
///
/// 距离计算方式：
/// - 使用曼哈顿距离：|x1 - x2| + |y1 - y2|
/// - 不考虑路径阻挡，只计算直线距离
///
/// 使用场景：
/// - 敌人AI自动攻击时选择目标
/// - 敌人回合开始时确定攻击目标
/// - 需要为敌人显示攻击目标提示时
///
/// 注意事项：
/// - 函数不检查目标是否在攻击范围内，只找最近的目标
/// - 不排除敌人自身（通过 id 比较排除）
/// - 如果多个目标距离相同，返回第一个找到的
/// - 当前实现不包含可达性判断，未来可能需要添加路径检查
/// - 如果玩家通过围堵策略使最近目标无法攻击，可以考虑选择第二近的目标
fn Enemy::find_nearest_attack_target(enemy : Enemy) -> CanAttackTarget? {
  let position_list = []
  let (self_x, self_y) = enemy.position
  let copper_list = get_battle_copper_list()
  for copper in copper_list {
    position_list.push((copper.position, CanAttackTarget::Copper(copper)))
  }
  for other_enemy in enemy_map.values() {
    if other_enemy.id != enemy.id && other_enemy.owned {
      position_list.push(
        (other_enemy.position, CanAttackTarget::Enemy(other_enemy)),
      )
    }
  }
  for structure in structure_map.values() {
    if structure.owned == true {
      position_list.push(
        (structure.position, CanAttackTarget::Structure(structure)),
      )
    }
  }
  let mut min_distance = 1000000000
  let mut nearest_target = None
  for position in position_list {
    let ((x, y), target) = position
    let distance = (x - self_x).abs() + (y - self_y).abs()
    if distance < min_distance {
      min_distance = distance
      nearest_target = Some(target)
    }
  }
  nearest_target
}

///|
/// 获取敌人当前可以移动到的所有位置列表
///
/// 该函数根据敌人的移动速度（speed），计算敌人周围所有可以移动到的位置。
/// 函数会检查每个位置是否被占用或超出地图边界，只返回合法的移动位置。
///
/// 参数说明：
/// - enemy: 需要获取可移动位置的敌人实例
/// - map: 当前游戏地图实例，用于检查位置占用情况和地图边界
///
/// 返回值：
/// - 返回 (Int, Int) 数组，包含所有可以移动到的位置坐标
/// - 空数组表示当前没有可移动位置（可能被完全包围）
///
/// 移动范围计算：
/// - 使用 generate_offset(enemy.enemy_base.speed) 生成所有在移动范围内的位置偏移
/// - 对于每个偏移位置，计算实际坐标 = enemy.position + offset
/// - 使用 map.is_occupy_or_out_of_map() 检查位置是否合法
///
/// 位置合法性判断：
/// - 位置必须在地图范围内
/// - 位置不能被其他单位占用（铜偶、敌人、建筑、材料等）
///
/// 使用场景：
/// - 显示敌人可移动范围时
/// - 敌人AI选择移动目标时
/// - 玩家查看敌人移动能力时
///
/// 注意事项：
/// - 移动范围是正方形范围，不是圆形范围
/// - 函数不检查路径阻挡，只检查目标位置是否可用
/// - 野生敌人和友方召唤物使用相同的移动逻辑
fn Enemy::get_can_move(enemy : Enemy, map : Map_) -> Array[(Int, Int)] {
  let offset = generate_offset(enemy.enemy_base.speed)
  let can_move = []
  for offset_ in offset {
    let position = (enemy.position.0 + offset_.0, enemy.position.1 + offset_.1)
    if !map.is_occupy_or_out_of_map(position) {
      can_move.push(position)
    }
  }
  can_move
}

///|
/// 更新敌人的局内状态并发送到前端用于UI显示
///
/// 该函数用于同步敌人的可移动和可攻击状态到前端界面。函数会先清除敌人的
/// 所有状态显示，然后根据敌人的实际状态（can_move、can_attack）发送相应的
/// 状态更新消息，让前端UI能够正确显示敌人的行动能力。
///
/// 参数说明：
/// - enemy: 需要更新状态的敌人实例
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 调用 clear_state(enemy.id) 清除敌人的所有状态显示
/// 2. 如果 enemy.can_move 为 true，调用 display_can_move(enemy.id, true) 显示可移动状态
/// 3. 如果 enemy.can_attack 为 true，调用 display_can_attack(enemy.id, true) 显示可攻击状态
///
/// 使用场景：
/// - 敌人回合开始时更新状态显示
/// - 敌人执行行动后更新状态
/// - 游戏状态变化时需要同步UI时
///
/// 注意事项：
/// - 函数只发送 true 状态，false 状态通过 clear_state 清除
/// - 敌人没有召唤和建造能力，所以不更新这些状态
/// - 状态更新是异步的，通过消息队列发送到前端
fn Enemy::update_move_and_attack_and_summon_status(enemy : Enemy) -> Unit {
  clear_state(enemy.id)
  if enemy.can_move {
    display_can_move(enemy.id, true)
  }
  if enemy.can_attack {
    display_can_attack(enemy.id, true)
  }
}
