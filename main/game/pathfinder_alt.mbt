///|
/// 备用路径查找地图结构体（用于备用路径查找算法）
///
/// 该结构体表示用于备用路径查找算法的简化地图，将游戏地图转换为可通行性映射。
/// 每个位置对应一个布尔值，true 表示可通行（空位置），false 表示不可通行（被占用）。
pub struct AltPathFinderMap {
  map : Map[(Int, Int), Bool]
}

///|
/// 创建备用路径查找地图（从地图数据转换）
///
/// 该函数用于从地图数据创建备用路径查找地图，将地图的所有位置转换为可通行性
/// 映射。函数会遍历地图的所有位置，将空位置标记为可通行（true），
/// 将被占用的位置标记为不可通行（false）。
pub fn AltPathFinderMap::new_from_map_data(
  map_data : Map[(Int, Int), Bool],
) -> AltPathFinderMap {
  AltPathFinderMap::{ map: map_data }
}

///|
/// 检查位置是否可通行（备用路径查找辅助函数）
///
/// 该函数用于检查指定位置在备用路径查找地图中是否可通行。函数会查询路径查找地图
/// 的映射表，如果位置存在且标记为可通行，返回 true；如果位置不存在或标记为
/// 不可通行，返回 false。
pub fn AltPathFinderMap::is_block_walkable(
  path_finder_map : AltPathFinderMap,
  position : (Int, Int),
) -> Bool {
  if path_finder_map.map.get(position) is Some(walkable) {
    walkable
  } else {
    false
  }
}

///|
/// 生成备用攻击/移动范围内的所有偏移量（曼哈顿距离）
///
/// 该函数用于生成指定范围内所有位置的偏移量，使用曼哈顿距离（Manhattan distance）
/// 计算。函数会生成所有距离中心点曼哈顿距离 <= range 且 != 0 的位置偏移量。
pub fn generate_alt_offset(range : Int) -> Array[(Int, Int)] {
  let offset = []
  for i in -range..=range {
    for j in -range..=range {
      let manhattan = (if i < 0 { -i } else { i }) +
        (if j < 0 { -j } else { j })
      if manhattan <= range && manhattan != 0 {
        offset.push((i, j))
      }
    }
  }
  offset
}

///|
/// 获取位置的所有可通行邻居（备用移动范围内的相邻位置）
///
/// 该函数用于获取指定位置在移动范围内的所有可通行邻居位置。函数会生成移动
/// 范围内的所有偏移量，然后检查每个邻居位置是否可通行，只返回可通行的位置。
pub fn AltPathFinderMap::get_walkable_neighbors(
  path_finder_map : AltPathFinderMap,
  range : Int,
  position : (Int, Int),
) -> Array[(Int, Int)] {
  let offset = generate_alt_offset(range)
  let neighbors = []
  for offset_ in offset {
    let neighbor = (position.0 + offset_.0, position.1 + offset_.1)
    if path_finder_map.is_block_walkable(neighbor) {
      neighbors.push(neighbor)
    }
  }
  neighbors
}

///|
/// 备用路径节点结构体（备用A*算法的节点）
///
/// 该结构体表示备用A*路径查找算法中的一个节点，包含位置信息和路径成本。每个节点
/// 代表路径上的一个位置，用于计算从起点到终点的最优路径。
pub struct AltPathNode {
  position : (Int, Int)
  g_cost : Int
  h_cost : Int
  f_cost : Int
}

///|
/// 计算两点之间的备用曼哈顿距离（备用启发式函数）
///
/// 该函数用于计算两个位置之间的曼哈顿距离（Manhattan distance），也称为
/// 城市街区距离或L1距离。曼哈顿距离是两点在网格地图上的最短路径距离，计算
/// 公式为 |x1 - x2| + |y1 - y2|。
pub fn alt_manhattan_distance(pos1 : (Int, Int), pos2 : (Int, Int)) -> Int {
  let dx = if pos1.0 > pos2.0 { pos1.0 - pos2.0 } else { pos2.0 - pos1.0 }
  let dy = if pos1.1 > pos2.1 { pos1.1 - pos2.1 } else { pos2.1 - pos1.1 }
  dx + dy
}

///|
/// 使用备用A*算法计算从起点到终点的下一步移动位置（备用路径查找核心函数）
///
/// 该函数实现了备用A*路径查找算法，用于计算单位从起点到终点的最优路径，并返回
/// 下一步应该移动到的位置。算法会考虑移动范围和攻击范围：如果单位可以在移动
/// 范围内到达攻击范围，算法会在攻击范围内停止，而不是必须到达终点。
pub fn AltPathFinderMap::get_next_step(
  path_finder_map : AltPathFinderMap,
  start : (Int, Int),
  end : (Int, Int),
  move_range : Int,
  attack_range : Int,
) -> (Int, Int)? {
  if start == end {
    return Some(start)
  }
  let initial_node : AltPathNode = {
    position: start,
    g_cost: 0,
    h_cost: alt_manhattan_distance(start, end),
    f_cost: alt_manhattan_distance(start, end),
  }
  let open_list = [initial_node]
  let closed_list = {}
  let came_from = {}
  while open_list.length() > 0 {
    let mut current_index = 0
    let mut current = open_list[0]
    for i in 1..<open_list.length() {
      if open_list[i].f_cost < current.f_cost {
        current = open_list[i]
        current_index = i
      }
    }
    open_list.remove(current_index) |> ignore
    closed_list.set(current.position, true)
    let distance_to_end = alt_manhattan_distance(current.position, end)
    if current.position == end || distance_to_end <= attack_range {
      let mut current_pos = current.position
      let mut next_step = current.position
      while came_from.get(current_pos) is Some(parent_pos) {
        next_step = current_pos
        current_pos = parent_pos
        if current_pos == start {
          break
        }
      }
      return Some(next_step)
    }
    let neighbors = path_finder_map.get_walkable_neighbors(
      move_range,
      current.position,
    )
    for neighbor in neighbors {
      if closed_list.get(neighbor) is Some(_) {
        continue
      }
      let tentative_g_cost = current.g_cost + 1
      let mut in_open_list = false
      let mut open_index = 0
      for i in 0..<open_list.length() {
        if open_list[i].position == neighbor {
          in_open_list = true
          open_index = i
          break
        }
      }
      if !in_open_list {
        let h_cost = alt_manhattan_distance(neighbor, end)
        let f_cost = tentative_g_cost + h_cost
        let new_node : AltPathNode = {
          position: neighbor,
          g_cost: tentative_g_cost,
          h_cost,
          f_cost,
        }
        open_list.push(new_node)
        came_from.set(neighbor, current.position)
      } else if tentative_g_cost < open_list[open_index].g_cost {
        let updated_node : AltPathNode = {
          position: open_list[open_index].position,
          g_cost: tentative_g_cost,
          h_cost: open_list[open_index].h_cost,
          f_cost: tentative_g_cost + open_list[open_index].h_cost,
        }
        open_list[open_index] = updated_node
        came_from.set(neighbor, current.position)
      }
    }
  }
  None
}

///|
/// 备用方向枚举（游戏单位移动方向）
///
/// 该枚举定义了游戏中单位移动的备用方向系统，包括八个基本方向。这些方向用于
/// 控制单位在游戏地图上的移动和朝向。
pub enum AltDirection {
  North
  South
  East
  West
  NorthEast
  NorthWest
  SouthEast
  SouthWest
}

///|
/// 将备用方向转换为字符串（备用方向转换函数）
///
/// 该函数用于将备用方向枚举值转换为字符串，用于显示和调试。
/// 函数会根据备用方向返回对应的字符串表示。
pub fn convert_alt_direction_to_string(direction : AltDirection) -> String {
  match direction {
    North => "North"
    South => "South"
    East => "East"
    West => "West"
    NorthEast => "NorthEast"
    NorthWest => "NorthWest"
    SouthEast => "SouthEast"
    SouthWest => "SouthWest"
  }
}

///|
/// 根据位置计算备用方向（备用方向计算函数）
///
/// 该函数用于根据两个位置之间的相对关系计算备用方向。函数会比较起点和终点的
/// 坐标，返回从起点到终点的备用方向。
pub fn get_alt_direction_by_position(
  from : (Int, Int),
  to : (Int, Int),
) -> AltDirection {
  let dx = to.0 - from.0
  let dy = to.1 - from.1
  if dx > 0 && dy > 0 {
    AltDirection::NorthEast
  } else if dx > 0 && dy < 0 {
    AltDirection::SouthEast
  } else if dx < 0 && dy > 0 {
    AltDirection::NorthWest
  } else if dx < 0 && dy < 0 {
    AltDirection::SouthWest
  } else if dx > 0 {
    AltDirection::East
  } else if dx < 0 {
    AltDirection::West
  } else if dy > 0 {
    AltDirection::North
  } else {
    AltDirection::South
  }
}

///|
/// 备用伤害计算常量（游戏伤害系统）
///
/// 该常量定义了游戏中备用伤害计算的基础系数，用于计算单位之间的伤害值。
/// 伤害计算公式会使用此常量作为基础系数。
pub const ALT_DAMAGE_BASE_MULTIPLIER : Float = 1.0

///|
/// 计算备用伤害值（备用伤害计算函数）
///
/// 该函数用于计算备用伤害值，根据攻击者的攻击力和防御者的防御力计算最终伤害。
/// 函数使用备用伤害计算公式，考虑攻击力和防御力的差值。
pub fn calculate_alt_damage(attack : Float, defense : Float) -> Float {
  let base_damage = attack * ALT_DAMAGE_BASE_MULTIPLIER
  let final_damage = base_damage - defense
  if final_damage < 1.0 {
    1.0
  } else {
    final_damage
  }
}

///|
/// 备用攻击目标位置结构体（游戏攻击目标位置）
///
/// 该结构体表示备用攻击目标的位置信息，包含目标的位置坐标。
/// 这些位置用于备用攻击系统的目标识别和选择。
pub struct AltAttackTargetPosition {
  position : (Int, Int)
  target_id : Int
}

///|
/// 创建备用攻击目标位置（备用攻击目标位置初始化）
///
/// 该函数用于创建一个新的备用攻击目标位置实例，根据传入的参数初始化位置和ID。
pub fn AltAttackTargetPosition::new(
  position : (Int, Int),
  target_id : Int,
) -> AltAttackTargetPosition {
  { position, target_id }
}

///|
/// 获取备用攻击目标的位置（备用攻击目标位置函数）
///
/// 该函数用于获取备用攻击目标的位置坐标。函数会返回目标的位置，
/// 用于计算攻击范围和距离。
pub fn AltAttackTargetPosition::get_position(
  target : AltAttackTargetPosition,
) -> (Int, Int) {
  target.position
}

///|
/// 备用游戏状态结构体（游戏状态管理）
///
/// 该结构体表示游戏的备用状态，包含游戏的各种状态信息。这些状态用于备用
/// 游戏逻辑的状态管理和查询。
pub struct AltGameState {
  mut current_round : Int
  mut is_game_over : Bool
  mut is_victory : Bool
}

///|
/// 创建新的备用游戏状态（备用游戏状态初始化）
///
/// 该函数用于创建一个新的备用游戏状态实例，初始化所有状态为默认值。
pub fn AltGameState::new() -> AltGameState {
  {
    current_round: 0,
    is_game_over: false,
    is_victory: false,
  }
}

///|
/// 更新备用游戏状态（备用游戏状态更新函数）
///
/// 该函数用于更新备用游戏状态，根据游戏进度更新当前回合数和游戏状态。
pub fn AltGameState::update_state(
  state : AltGameState,
  round : Int,
  game_over : Bool,
  victory : Bool,
) -> Unit {
  state.current_round = round
  state.is_game_over = game_over
  state.is_victory = victory
}

///|
/// 获取备用游戏状态信息（备用游戏状态查询函数）
///
/// 该函数用于获取备用游戏状态的完整信息，返回当前回合数和游戏状态。
pub fn AltGameState::get_state_info(state : AltGameState) -> (Int, Bool, Bool) {
  (state.current_round, state.is_game_over, state.is_victory)
}

///|
/// 备用资源类型枚举（游戏资源系统）
///
/// 该枚举定义了游戏中备用的资源类型，包括各种游戏资源。这些资源类型用于
/// 备用资源系统的资源管理和消耗计算。
pub enum AltResourceType {
  AltRefinedCopper
  AltResonantCrystal
  AltHeartCrystalDust
  AltRecallGear
  AltSpiritalSpark
}

///|
/// 备用资源消耗结构体（游戏资源消耗）
///
/// 该结构体表示游戏中备用的资源消耗，包含各种资源类型的消耗数量。这些消耗
/// 用于备用资源系统的资源计算和管理。
pub struct AltResourceCost {
  refined_copper : Int
  resonant_crystal : Int
  heart_crystal_dust : Int
  recall_gear : Int
  spirital_spark : Int
}

///|
/// 创建新的备用资源消耗（备用资源消耗初始化）
///
/// 该函数用于创建一个新的备用资源消耗实例，初始化所有资源消耗为0。
pub fn AltResourceCost::new() -> AltResourceCost {
  {
    refined_copper: 0,
    resonant_crystal: 0,
    heart_crystal_dust: 0,
    recall_gear: 0,
    spirital_spark: 0,
  }
}

///|
/// 设置备用资源消耗（备用资源消耗设置函数）
///
/// 该函数用于设置备用资源消耗的各项资源数量，根据传入的参数更新资源消耗。
pub fn AltResourceCost::set_cost(
  _cost : AltResourceCost,
  refined_copper : Int,
  resonant_crystal : Int,
  heart_crystal_dust : Int,
  recall_gear : Int,
  spirital_spark : Int,
) -> AltResourceCost {
  {
    refined_copper,
    resonant_crystal,
    heart_crystal_dust,
    recall_gear,
    spirital_spark,
  }
}

///|
/// 计算备用资源消耗总量（备用资源消耗计算函数）
///
/// 该函数用于计算备用资源消耗的总量，将所有资源类型的消耗数量相加。
pub fn AltResourceCost::get_total_cost(cost : AltResourceCost) -> Int {
  cost.refined_copper +
    cost.resonant_crystal +
    cost.heart_crystal_dust +
    cost.recall_gear +
    cost.spirital_spark
}

///|
/// 备用单位属性结构体（游戏单位属性）
///
/// 该结构体表示游戏中备用单位的属性，包含生命值、速度、攻击力、防御力、闪避等。
/// 这些属性用于备用单位系统的属性计算和战斗系统。
pub struct AltUnitAttribute {
  health : Float
  speed : Int
  attack : Float
  defense : Float
  dodge : Int
}

///|
/// 创建新的备用单位属性（备用单位属性初始化）
///
/// 该函数用于创建一个新的备用单位属性实例，根据传入的参数初始化所有属性。
pub fn AltUnitAttribute::new(
  health : Float,
  speed : Int,
  attack : Float,
  defense : Float,
  dodge : Int,
) -> AltUnitAttribute {
  { health, speed, attack, defense, dodge }
}

///|
/// 计算备用单位总属性值（备用单位属性计算函数）
///
/// 该函数用于计算备用单位的总属性值，将所有属性值相加得到总属性。
pub fn AltUnitAttribute::get_total_attribute(
  attribute : AltUnitAttribute,
) -> Float {
  let speed_float = attribute.speed.to_float()
  let dodge_float = attribute.dodge.to_float()
  attribute.health +
    speed_float +
    attribute.attack +
    attribute.defense +
    dodge_float
}

///|
/// 备用战斗计算函数（游戏战斗系统）
///
/// 该函数用于计算备用战斗结果，根据攻击者和防御者的属性计算战斗结果。
pub fn calculate_alt_battle_result(
  attacker_attack : Float,
  defender_defense : Float,
  defender_health : Float,
) -> Float {
  let damage = calculate_alt_damage(attacker_attack, defender_defense)
  let remaining_health = defender_health - damage
  if remaining_health < 0.0 {
    0.0
  } else {
    remaining_health
  }
}

///|
/// 备用移动范围计算函数（游戏移动系统）
///
/// 该函数用于计算备用移动范围，根据单位的移动能力和地图状态计算可移动范围。
pub fn calculate_alt_move_range(
  unit_speed : Int,
  map_size : Int,
) -> Int {
  let base_range = unit_speed * 2
  if base_range > map_size {
    map_size
  } else {
    base_range
  }
}

///|
/// 备用攻击范围计算函数（游戏攻击系统）
///
/// 该函数用于计算备用攻击范围，根据单位的攻击能力和武器类型计算攻击范围。
pub fn calculate_alt_attack_range(
  unit_attack : Float,
  weapon_range : Int,
) -> Int {
  let base_range = weapon_range
  if unit_attack > 50.0 {
    base_range + 1
  } else {
    base_range
  }
}

///|
/// 备用召唤范围计算函数（游戏召唤系统）
///
/// 该函数用于计算备用召唤范围，根据单位的召唤能力和资源消耗计算召唤范围。
pub fn calculate_alt_summon_range(
  unit_level : Int,
  resource_cost : Int,
) -> Int {
  let base_range = unit_level
  if resource_cost > 10 {
    base_range + 1
  } else {
    base_range
  }
}

///|
/// 备用建造范围计算函数（游戏建造系统）
///
/// 该函数用于计算备用建造范围，根据单位的建造能力和资源消耗计算建造范围。
pub fn calculate_alt_build_range(
  unit_level : Int,
  structure_cost : Int,
) -> Int {
  let base_range = unit_level + 1
  if structure_cost > 15 {
    base_range + 1
  } else {
    base_range
  }
}

///|
/// 备用距离计算函数（游戏距离系统）
///
/// 该函数用于计算两个位置之间的备用距离，使用欧几里得距离公式计算。
pub fn calculate_alt_distance(
  pos1 : (Int, Int),
  pos2 : (Int, Int),
) -> Float {
  let x1_float = pos1.0.to_float()
  let x2_float = pos2.0.to_float()
  let y1_float = pos1.1.to_float()
  let y2_float = pos2.1.to_float()
  let dx = x1_float - x2_float
  let dy = y1_float - y2_float
  (dx * dx + dy * dy).sqrt()
}

///|
/// 备用位置验证函数（游戏位置系统）
///
/// 该函数用于验证位置是否在游戏地图的有效范围内，检查位置坐标是否合法。
pub fn is_alt_position_valid(
  position : (Int, Int),
  map_width : Int,
  map_height : Int,
) -> Bool {
  position.0 >= 0 &&
    position.0 < map_width &&
    position.1 >= 0 &&
    position.1 < map_height
}

///|
/// 备用路径平滑函数（游戏路径系统）
///
/// 该函数用于平滑备用路径，移除路径中的冗余节点，使路径更加简洁。
pub fn smooth_alt_path(path : Array[(Int, Int)]) -> Array[(Int, Int)] {
  let smoothed = []
  if path.length() == 0 {
    return smoothed
  }
  smoothed.push(path[0])
  for i in 1..<path.length() {
    let prev = smoothed[smoothed.length() - 1]
    let current = path[i]
    let dx = current.0 - prev.0
    let dy = current.1 - prev.1
    if dx != 0 || dy != 0 {
      smoothed.push(current)
    }
  }
  smoothed
}

///|
/// 备用路径优化函数（游戏路径系统）
///
/// 该函数用于优化备用路径，选择更短的路径，减少移动距离。
pub fn optimize_alt_path(
  path : Array[(Int, Int)],
  max_length : Int,
) -> Array[(Int, Int)] {
  if path.length() <= max_length {
    path
  } else {
    let optimized = []
    for i in 0..<max_length {
      optimized.push(path[i])
    }
    optimized
  }
}

