///|
let battle_copper_map : Map[Int, BattleCopper] = Map::new()

///|
/// 铜偶的战斗临时状态
/// 也就是正常铜偶的属性上添加了新的一层 ID 和局内状态
/// 局内状态包括可移动、可攻击、可召唤、可建造
/// 游戏结束时，所有战斗铜偶都会被删除
priv struct BattleCopper {
  id : Int
  original_id : Int
  copper : Copper
  mut can_move : Bool // 可移动状态，如果为 false，前端应该不允许点击移动按钮
  mut can_attack : Bool // 可攻击状态，如果为 false，前端应该不允许点击攻击按钮
  mut can_summon : Bool // 可召唤状态，如果为 false，前端应该不允许点击召唤按钮
  mut can_build : Bool // 可建造状态，如果为 false，前端应该不允许点击建造按钮
  mut position : (Int, Int)
  mut now_health : Float
  attribute : Attribute
} derive(ToJson)

///|
/// 根据唯一ID从全局战斗铜偶映射表中获取对应的战斗铜偶实例
///
/// 该函数用于通过ID快速查找战斗中的铜偶。战斗铜偶是游戏进行时创建的临时实例，
/// 包含了铜偶的原始信息以及局内的战斗状态（位置、生命值、可行动状态等）。
///
/// 参数说明：
/// - id: 战斗铜偶的唯一标识符，在创建时由 id_pool 分配
///
/// 返回值：
/// - 返回对应的 BattleCopper 实例
/// - 如果ID不存在会触发 panic（使用 unwrap()）
///
/// 使用场景：
/// - 通过前端传来的ID查找对应的铜偶
/// - 事件处理函数中根据ID获取铜偶进行操作
/// - 需要访问特定铜偶的状态时
///
/// 注意事项：
/// - 函数使用 unwrap()，如果ID不存在会导致程序崩溃
/// - 确保传入的ID是有效的战斗铜偶ID
/// - 战斗结束后所有战斗铜偶会被清除，此时调用会失败
fn get_battle_copper_by_id(id : Int) -> BattleCopper {
  battle_copper_map.get(id).unwrap()
}

///|
/// 创建战斗铜偶实例并添加到全局战斗铜偶映射表
///
/// 该函数用于将普通铜偶转换为战斗铜偶，并设置初始的战斗状态。战斗铜偶包含了
/// 铜偶的原始信息以及局内的临时状态（位置、生命值、可行动能力等）。根据铜偶
/// 类型的不同，会设置不同的初始能力：工匠和共鸣者不能攻击，共鸣者可以召唤，
/// 工匠可以建造。
///
/// 参数说明：
/// - copper: 原始铜偶实例，包含铜偶的所有基础信息（类型、属性、装备等）
/// - original_id: 原始铜偶的ID，用于关联全局铜偶数据
/// - position: 战斗铜偶在地图上的初始位置坐标 (x, y)
///
/// 返回值：
/// - 返回创建的 BattleCopper 实例，已自动添加到 battle_copper_map 中
///
/// 初始状态设置：
/// - can_move: 默认为 true，所有铜偶初始都可以移动
/// - can_attack: 根据铜偶类型设置，工匠和共鸣者为 false，其他为 true
/// - can_summon: 只有共鸣者类型为 true，其他为 false
/// - can_build: 只有工匠类型为 true，其他为 false
/// - now_health: 初始化为铜偶的最大生命值（copper.attribute.health）
///
/// 使用场景：
/// - 游戏开始时将玩家选择的铜偶加入战斗
/// - 需要创建战斗铜偶实例时
///
/// 注意事项：
/// - 函数会自动为战斗铜偶分配新的唯一ID
/// - 战斗铜偶的生命值初始为满血
/// - 战斗结束后所有战斗铜偶会被清除
fn BattleCopper::new(
  copper : Copper,
  original_id : Int,
  position : (Int, Int),
) -> BattleCopper {
  // 根据铜偶类型设置攻击能力：工匠和共鸣者不能攻击
  let can_attack = match copper.copper_type {
    CraftsMan | Resonator => false
    _ => true
  }
  let battle_copper = BattleCopper::{
    id: id_pool.get_id(),
    copper,
    original_id,
    can_move: true,
    can_attack,
    can_summon: copper.copper_type is Resonator,
    can_build: copper.copper_type is CraftsMan,
    position,
    now_health: copper.attribute.health,
    attribute: copper.attribute,
  }
  battle_copper_map.set(battle_copper.id, battle_copper)
  battle_copper
}

///|
/// 处理战斗铜偶受到攻击的伤害结算逻辑
///
/// 该函数实现了完整的攻击结算流程：首先检查铜偶是否成功闪避攻击，如果闪避
/// 成功则不受伤害；如果未闪避，则根据攻击力和防御力计算实际伤害值，并扣除
/// 铜偶的生命值。最后返回铜偶是否被击杀。
///
/// 参数说明：
/// - battle_copper: 受到攻击的战斗铜偶实例（可变引用）
/// - attack: 攻击者的攻击力数值
///
/// 返回值：
/// - 返回 Bool 类型，true 表示铜偶被击杀（生命值 <= 0），false 表示铜偶存活
///
/// 伤害计算公式：
/// - 首先计算闪避概率：battle_copper.attribute.dodge / 100
/// - 如果闪避成功，直接返回 false（未击杀）
/// - 如果未闪避，使用 calculate_damage(attack, defense) 计算实际伤害
/// - 实际伤害 = 攻击力 * (攻击力 / (攻击力 + 防御力 * K))
/// - 最终伤害会从 battle_copper.now_health 中扣除
///
/// 使用场景：
/// - 敌人攻击铜偶时
/// - 敌方建筑攻击铜偶时
/// - 其他铜偶攻击该铜偶时（友军误伤等特殊情况）
///
/// 注意事项：
/// - 函数会直接修改 battle_copper.now_health 的值
/// - 闪避判定使用概率检查，可能受到随机数影响
/// - 伤害计算考虑了防御力的减伤效果
/// - 生命值可能为负数，但判断击杀时使用 <= 0
fn BattleCopper::apply_attack(
  battle_copper : BattleCopper,
  attack : Float,
) -> Bool {
  if check_probability(battle_copper.attribute.dodge.to_double() / 100) {
    return false
  }
  let damage = calculate_damage(attack, battle_copper.attribute.defense)
  battle_copper.now_health -= damage
  battle_copper.now_health <= 0
}

///|
/// 处理战斗铜偶受到治疗的效果结算
///
/// 该函数用于处理维修工坊或机械师铜偶对战斗铜偶的治疗效果。治疗会直接增加
/// 铜偶的生命值，但不会超过铜偶的最大生命值。这是一个纯增益效果，不会造成
/// 任何负面状态。
///
/// 参数说明：
/// - battle_copper: 受到治疗的战斗铜偶实例（可变引用）
/// - attack: 治疗量数值（这里使用 attack 参数名是因为治疗和攻击使用相同的
///           数值系统，但实际是治疗量而非伤害）
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 治疗逻辑：
/// - 直接将治疗量加到 battle_copper.now_health
/// - 如果治疗后生命值超过最大生命值，则设置为最大生命值
/// - 公式：now_health = min(now_health + heal_amount, max_health)
///
/// 使用场景：
/// - 维修工坊对铜偶进行治疗时
/// - 机械师铜偶使用治疗技能时
/// - 任何需要恢复铜偶生命值的场景
///
/// 注意事项：
/// - 函数会直接修改 battle_copper.now_health 的值
/// - 治疗不会超过最大生命值，防止溢出
/// - 参数名使用 attack 是历史遗留，实际是治疗量
fn BattleCopper::apply_mechanic_heal(
  battle_copper : BattleCopper,
  attack : Float,
) -> Unit {
  battle_copper.now_health += attack
  if battle_copper.now_health > battle_copper.attribute.health {
    battle_copper.now_health = battle_copper.attribute.health
  }
}

///|
/// 获取战斗铜偶的攻击范围数值
///
/// 该函数用于获取铜偶的攻击范围，优先使用铜偶信息中自定义的攻击范围（用于
/// 召唤物等特殊情况），如果没有自定义则根据铜偶类型返回默认的攻击范围。不同
/// 类型的铜偶有不同的攻击范围：铁壁为1，奥术师为3，机械师为1，共鸣者和工匠
/// 没有攻击能力返回0。
///
/// 参数说明：
/// - battle_copper: 需要获取攻击范围的战斗铜偶实例
///
/// 返回值：
/// - 返回 Int 类型，表示攻击范围（以格子为单位）
/// - 返回 0 表示该铜偶没有攻击能力
///
/// 优先级规则：
/// 1. 优先检查 battle_copper.copper.copper_info.attack_range
///    如果存在自定义攻击范围，直接返回该值（用于召唤物等特殊情况）
/// 2. 如果没有自定义，根据铜偶类型返回默认值：
///    - IronWall（铁壁）: 1
///    - Arcanist（奥术师）: 3
///    - Mechanic（机械师）: 1
///    - Resonator（共鸣者）: 0（无攻击能力）
///    - CraftsMan（工匠）: 0（无攻击能力）
///
/// 使用场景：
/// - 计算铜偶可攻击目标时
/// - 显示铜偶攻击范围时
/// - 判断铜偶是否可以攻击某个位置时
///
/// 注意事项：
/// - 攻击范围是正方形范围，不是圆形范围
/// - 返回0表示该铜偶完全不能攻击
/// - 召唤物可能通过 copper_info.attack_range 覆盖默认值
fn BattleCopper::get_attack_range(battle_copper : BattleCopper) -> Int {
  // 优先使用 copper_info 中的自定义攻击范围（用于召唤物）
  match battle_copper.copper.copper_info.attack_range {
    Some(range) => range
    None =>
      match battle_copper.copper.copper_type {
        IronWall => 1
        Arcanist => 3
        Mechanic => 1
        Resonator | CraftsMan => 0 // 无攻击能力的单位返回0（会生成空攻击范围）
      }
  }
}

///|
/// 获取战斗铜偶在当前攻击范围内可以攻击的所有目标列表
///
/// 该函数根据铜偶的攻击范围，计算铜偶周围所有可攻击的位置，并检查这些位置
/// 上是否有可攻击的目标。铜偶只能攻击特定类型的目标：机械师铜偶（用于治疗）、
/// 敌方建筑、敌方敌人。其他类型的单位（友方铜偶、友方建筑等）不能作为攻击目标。
///
/// 参数说明：
/// - battle_copper: 需要获取攻击目标的战斗铜偶实例
/// - map: 当前游戏地图实例，用于查询位置占用情况和获取占用者信息
///
/// 返回值：
/// - 返回 CanAttackTarget 数组，包含所有在攻击范围内的可攻击目标
/// - 可能的目标类型包括：Copper（机械师铜偶，用于治疗）、Enemy（敌方敌人）、
///   Structure（敌方建筑）
/// - 空数组表示当前没有可攻击目标
///
/// 攻击范围计算：
/// - 使用 get_attack_range() 获取铜偶的攻击范围
/// - 使用 generate_offset(attack_range) 生成所有在攻击范围内的位置偏移
/// - 对于每个偏移位置，计算实际坐标 = battle_copper.position + offset
/// - 检查该位置是否被占用，如果占用则进一步判断占用者类型
///
/// 目标判断逻辑：
/// - Copper（铜偶）: 只能攻击机械师类型的铜偶（用于治疗友军）
/// - Structure（建筑）: 只能攻击敌方建筑（owned == false）
/// - Enemy（敌人）: 只能攻击敌方敌人（owned == false）
/// - 其他类型的目标（友方铜偶、友方建筑等）不能攻击
///
/// 使用场景：
/// - 显示铜偶可攻击范围时
/// - 玩家选择攻击目标时
/// - 判断铜偶是否可以攻击某个位置时
///
/// 注意事项：
/// - 攻击范围是正方形范围，不是圆形范围
/// - 函数只返回在攻击范围内的目标，不考虑路径阻挡
/// - 机械师铜偶可以被攻击（用于治疗），这是特殊机制
fn BattleCopper::get_can_attack(
  battle_copper : BattleCopper,
  map : Map_,
) -> Array[CanAttackTarget] {
  let attack_range = battle_copper.get_attack_range()
  let offset = generate_offset(attack_range)
  let can_attack = []
  for offset_ in offset {
    let position = (
      battle_copper.position.0 + offset_.0,
      battle_copper.position.1 + offset_.1,
    )
    if map.is_occupy(position) {
      let occupant = map.get_occupant(position)
      match occupant {
        Copper(copper) if copper.copper.copper_type is Mechanic =>
          can_attack.push(CanAttackTarget::Copper(copper))
        Structure(structure) if structure.owned == false =>
          can_attack.push(CanAttackTarget::Structure(structure))
        Enemy(enemy) if enemy.owned == false =>
          can_attack.push(CanAttackTarget::Enemy(enemy))
        _ => ()
      }
    }
  }
  can_attack
}

///|
/// 获取战斗铜偶当前可以移动到的所有位置列表（包含复杂的移动规则）
///
/// 该函数根据铜偶的移动速度（speed），计算铜偶周围所有可以移动到的位置。
/// 函数实现了复杂的移动规则：包括位置占用检查、地图边界检查、距离房间检查
/// 以及对角线移动的特殊规则。对角线移动需要至少有一个相邻的"中转"位置可达。
///
/// 参数说明：
/// - battle_copper: 需要获取可移动位置的战斗铜偶实例
/// - map: 当前游戏地图实例，用于检查位置占用情况、地图边界和房间距离
///
/// 返回值：
/// - 返回 (Int, Int) 数组，包含所有可以移动到的位置坐标
/// - 空数组表示当前没有可移动位置（可能被完全包围或超出移动范围）
///
/// 移动范围计算：
/// - 使用 generate_offset(battle_copper.attribute.speed) 生成所有在移动范围内的位置偏移
/// - 对于每个偏移位置，计算实际坐标 = battle_copper.position + offset
///
/// 位置合法性判断（按顺序检查）：
/// 1. 距离房间检查：位置距离最近房间的距离必须 <= 1（允许超出地图边界1格）
/// 2. 占用检查：位置不能被其他单位占用（铜偶、敌人、建筑、材料等）
/// 3. 对角线移动特殊规则：
///    - 如果是对角线移动（dx != 0 && dy != 0），需要检查两个相邻的"中转"位置
///    - 两个中转位置至少有一个必须：距离房间 <= 1 且未被占用
///    - 如果两个中转位置都不可达，则不能进行对角线移动
///
/// 使用场景：
/// - 显示铜偶可移动范围时
/// - 玩家选择移动目标时
/// - 判断铜偶是否可以移动到某个位置时
///
/// 注意事项：
/// - 移动范围是正方形范围，不是圆形范围
/// - 对角线移动有特殊限制，需要相邻位置可达
/// - 允许超出地图边界1格，但不允许2格或更多
/// - 函数不检查路径阻挡，只检查目标位置和相邻位置的合法性
fn BattleCopper::get_can_move(
  battle_copper : BattleCopper,
  map : Map_,
) -> Array[(Int, Int)] {
  let offset = generate_offset(battle_copper.attribute.speed)
  let can_move = []
  for offset_ in offset {
    let position = (
      battle_copper.position.0 + offset_.0,
      battle_copper.position.1 + offset_.1,
    )
    // 允许：1) 地图内未占用的位置，或 2) 超出地图边界1格的位置（但不允许2格或更多）
    let distance_to_room = map.distance_to_nearest_room(position)
    if distance_to_room > 1 || map.is_occupy(position) {
      continue
    }

    // 对于对角线移动，需要检查是否有相邻的"中转"位置可达
    let dx = offset_.0
    let dy = offset_.1
    if dx != 0 && dy != 0 {
      // 对角线移动：检查两个相邻位置至少有一个距离房间<=1且未被占用
      let mid_pos1 = (battle_copper.position.0 + dx, battle_copper.position.1)
      let mid_pos2 = (battle_copper.position.0, battle_copper.position.1 + dy)
      let mid1_distance = map.distance_to_nearest_room(mid_pos1)
      let mid2_distance = map.distance_to_nearest_room(mid_pos2)
      let mid1_valid = mid1_distance <= 1 && !map.is_occupy(mid_pos1)
      let mid2_valid = mid2_distance <= 1 && !map.is_occupy(mid_pos2)
      if !mid1_valid && !mid2_valid {
        continue // 两个中转位置都不可达，不能对角线移动
      }
    }
    can_move.push(position)
  }
  can_move
}

///|
/// 获取战斗铜偶可以召唤新单位的所有位置列表
///
/// 该函数用于共鸣者类型的铜偶，计算其周围可以召唤新单位的位置。召唤位置限制
/// 在铜偶的四个相邻位置（上下左右），不包括对角线位置。这些位置必须是未被占用
/// 且在地图范围内的合法位置。
///
/// 参数说明：
/// - battle_copper: 需要获取召唤位置的战斗铜偶实例（通常是共鸣者类型）
/// - map: 当前游戏地图实例，用于检查位置占用情况和地图边界
///
/// 返回值：
/// - 返回 (Int, Int) 数组，包含所有可以召唤的位置坐标
/// - 空数组表示当前没有可召唤位置（可能被完全包围）
///
/// 召唤位置计算：
/// - 固定使用四个相邻位置的偏移：(-1, 0), (1, 0), (0, -1), (0, 1)
/// - 对于每个偏移位置，计算实际坐标 = battle_copper.position + offset
/// - 使用 map.is_occupy_or_out_of_map() 检查位置是否合法
///
/// 位置合法性判断：
/// - 位置必须在地图范围内（不能超出边界）
/// - 位置不能被其他单位占用（铜偶、敌人、建筑、材料等）
/// - 不包括对角线位置，只考虑上下左右四个方向
///
/// 使用场景：
/// - 显示共鸣者可召唤范围时
/// - 玩家选择召唤位置时
/// - 判断是否可以召唤到某个位置时
///
/// 注意事项：
/// - 只有共鸣者类型的铜偶才能召唤，其他类型调用此函数无意义
/// - 召唤位置固定为四个相邻位置，不受铜偶属性影响
/// - 空数组表示当前没有可召唤位置
fn BattleCopper::get_summon_position(
  battle_copper : BattleCopper,
  map : Map_,
) -> Array[(Int, Int)] {
  let result = []
  let offset = [(-1, 0), (1, 0), (0, -1), (0, 1)]
  for offset_ in offset {
    let position = (
      battle_copper.position.0 + offset_.0,
      battle_copper.position.1 + offset_.1,
    )
    if !map.is_occupy_or_out_of_map(position) {
      result.push(position)
    }
  }
  result
}

///|
/// 获取战斗铜偶可以建造建筑的所有位置列表
///
/// 该函数用于工匠类型的铜偶，计算其周围可以建造建筑的位置。建造位置限制在
/// 铜偶的四个相邻位置（上下左右），不包括对角线位置。根据建筑类型的不同，
/// 位置合法性判断规则也不同：矿钻需要在矿物上建造，普通建筑需要在空地上建造。
///
/// 参数说明：
/// - battle_copper: 需要获取建造位置的战斗铜偶实例（通常是工匠类型）
/// - map: 当前游戏地图实例，用于检查位置占用情况、地图边界和材料信息
/// - is_drill: 是否为矿钻建筑，true 表示矿钻，false 表示普通建筑
///
/// 返回值：
/// - 返回 (Int, Int) 数组，包含所有可以建造的位置坐标
/// - 空数组表示当前没有可建造位置
///
/// 建造位置计算：
/// - 固定使用四个相邻位置的偏移：(-1, 0), (1, 0), (0, -1), (0, 1)
/// - 对于每个偏移位置，计算实际坐标 = battle_copper.position + offset
///
/// 位置合法性判断（根据建筑类型）：
/// - 矿钻（is_drill = true）:
///   - 位置必须被占用（map.is_occupy(position) = true）
///   - 占用者必须是 Material（材料）类型
///   - 矿钻需要在矿物资源上建造
/// - 普通建筑（is_drill = false）:
///   - 位置必须未被占用（map.is_occupy_or_out_of_map(position) = false）
///   - 位置必须在地图范围内
///   - 普通建筑需要在空地上建造
///
/// 使用场景：
/// - 显示工匠可建造范围时
/// - 玩家选择建造位置时
/// - 判断是否可以建造到某个位置时
///
/// 注意事项：
/// - 只有工匠类型的铜偶才能建造，其他类型调用此函数无意义
/// - 建造位置固定为四个相邻位置，不受铜偶属性影响
/// - 矿钻和普通建筑的建造规则完全不同，需要正确传入 is_drill 参数
/// - 空数组表示当前没有可建造位置
fn BattleCopper::get_structure_build_position(
  battle_copper : BattleCopper,
  map : Map_,
  is_drill~ : Bool,
) -> Array[(Int, Int)] {
  let result = []
  let offset = [(-1, 0), (1, 0), (0, -1), (0, 1)]
  for offset_ in offset {
    let position = (
      battle_copper.position.0 + offset_.0,
      battle_copper.position.1 + offset_.1,
    )
    if is_drill {
      // 矿钻：需要在矿物上建造
      // is_occupy 在超出范围时返回 false，所以是安全的
      if map.is_occupy(position) &&
        map.force_get_map_block(position).occupant is Material(_) {
        result.push(position)
      }
      // 普通建筑：需要空地且没有资源
      // 先用 is_occupy_or_out_of_map 检查是否安全访问
    } else if !map.is_occupy_or_out_of_map(position) {
      result.push(position)
    }
  }
  result
}

///|
/// 更新战斗铜偶的局内状态并发送到前端用于UI显示
///
/// 该函数用于同步战斗铜偶的所有可行动状态到前端界面。函数会先清除铜偶的
/// 所有状态显示，然后根据铜偶的实际状态（can_move、can_attack、can_summon、
/// can_build）发送相应的状态更新消息，让前端UI能够正确显示铜偶的行动能力。
/// 注意：函数会始终发送状态消息，无论是 true 还是 false，用于修复前端状态显示问题。
///
/// 参数说明：
/// - copper: 需要更新状态的战斗铜偶实例
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 调用 clear_state(copper.id) 清除铜偶的所有状态显示
/// 2. 调用 display_can_move(copper.id, copper.can_move) 更新可移动状态
/// 3. 调用 display_can_attack(copper.id, copper.can_attack) 更新可攻击状态
/// 4. 调用 display_can_summon(copper.id, copper.can_summon) 更新可召唤状态
/// 5. 调用 display_can_build(copper.id, copper.can_build) 更新可建造状态
///
/// 使用场景：
/// - 铜偶回合开始时更新状态显示
/// - 铜偶执行行动后更新状态
/// - 游戏状态变化时需要同步UI时
/// - 需要修复前端状态显示问题时
///
/// 注意事项：
/// - 函数会发送所有状态（包括 true 和 false），而不仅仅是 true 状态
/// - 这有助于修复前端状态显示不一致的问题
/// - 状态更新是异步的，通过消息队列发送到前端
/// - 不同铜偶类型的状态不同（如工匠有建造能力，共鸣者有召唤能力）
fn BattleCopper::update_move_and_attack_and_summon_status(
  copper : BattleCopper,
) -> Unit {
  clear_state(copper.id)
  // 始终发送状态消息，无论是 true 还是 false,用于修复前端状态显示问题
  display_can_move(copper.id, copper.can_move)
  display_can_attack(copper.id, copper.can_attack)
  display_can_summon(copper.id, copper.can_summon)
  display_can_build(copper.id, copper.can_build)
}

///|
/// 获取当前战斗中所有战斗铜偶的列表
///
/// 该函数用于获取全局战斗铜偶映射表中所有的战斗铜偶实例，并转换为数组返回。
/// 战斗铜偶是游戏进行时创建的临时实例，包含了铜偶的原始信息以及局内的战斗状态。
/// 战斗结束后所有战斗铜偶会被清除。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回 BattleCopper 数组，包含所有当前战斗中的战斗铜偶实例
/// - 空数组表示当前没有战斗铜偶（游戏未开始或已结束）
///
/// 使用场景：
/// - 遍历所有战斗铜偶进行操作时
/// - 敌人AI查找攻击目标时
/// - 游戏状态统计和显示时
/// - 需要获取所有战斗单位时
///
/// 注意事项：
/// - 返回的是战斗铜偶，不是全局铜偶数据
/// - 战斗结束后调用会返回空数组
/// - 函数会创建新的数组，对返回值的修改不会影响原始映射表
fn get_battle_copper_list() -> Array[BattleCopper] {
  battle_copper_map.values().to_array()
}
