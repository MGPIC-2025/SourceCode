///|
/// 路径查找地图结构体（用于A*路径查找算法）
///
/// 该结构体表示用于路径查找算法的简化地图，将游戏地图转换为可通行性映射。
/// 每个位置对应一个布尔值，true 表示可通行（空位置），false 表示不可通行
/// （被占用）。这用于A*路径查找算法，计算单位从起点到终点的最优路径。
///
/// 字段说明：
/// - map: 全局坐标到可通行性的映射，键为位置坐标，值为是否可通行
priv struct PathFinderMap {
  map : Map[(Int, Int), Bool]
}

///|
/// 创建路径查找地图（从游戏地图转换）
///
/// 该函数用于从游戏地图创建路径查找地图，将游戏地图的所有位置转换为可通行性
/// 映射。函数会遍历游戏地图的所有房间和地图块，将空位置标记为可通行（true），
/// 将被占用的位置标记为不可通行（false）。这用于初始化A*路径查找算法。
///
/// 参数说明：
/// - map: 当前游戏地图实例
///
/// 返回值：
/// - 返回新创建的路径查找地图实例 PathFinderMap
///
/// 执行流程：
/// 1. 获取游戏地图的全局映射（map.get_global_map）
/// 2. 创建空的路径查找地图
/// 3. 遍历全局映射的所有位置和地图块：
///    a. 如果地图块的占用者为 Empty（空位置），标记为可通行（true）
///    b. 如果地图块的占用者不为 Empty（被占用），标记为不可通行（false）
/// 4. 返回创建的路径查找地图
///
/// 使用场景：
/// - 初始化路径查找算法时
/// - 需要计算单位移动路径时
///
/// 注意事项：
/// - 只有空位置才可通行，被占用的位置不可通行
/// - 路径查找地图是游戏地图的简化版本，只关注可通行性
/// - 地图创建后不会自动更新，需要重新创建以反映地图变化
fn PathFinderMap::new(map : Map_) -> PathFinderMap {
  let global_map = map.get_global_map()
  let path_finder_map = PathFinderMap::{ map: {} }
  for t in global_map {
    let (global_position, block) = t
    if block.occupant is Empty {
      path_finder_map.map.set(global_position, true)
    } else {
      path_finder_map.map.set(global_position, false)
    }
  }
  path_finder_map
}

///|
/// 检查位置是否可通行（路径查找辅助函数）
///
/// 该函数用于检查指定位置在路径查找地图中是否可通行。函数会查询路径查找地图
/// 的映射表，如果位置存在且标记为可通行，返回 true；如果位置不存在或标记为
/// 不可通行，返回 false。这用于A*算法判断位置是否可以作为路径的一部分。
///
/// 参数说明：
/// - path_finder_map: 路径查找地图实例
/// - position: 要检查的全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 位置可通行（空位置）
/// - false: 位置不可通行（被占用或不存在）
///
/// 使用场景：
/// - A*路径查找算法判断位置可通行性时
/// - 需要检查位置是否可用时
///
/// 注意事项：
/// - 如果位置不在映射表中，返回 false（视为不可通行）
/// - 只有空位置才可通行，被占用的位置不可通行
fn PathFinderMap::is_block_walkable(
  path_finder_map : PathFinderMap,
  position : (Int, Int),
) -> Bool {
  if path_finder_map.map.get(position) is Some(walkable) {
    walkable
  } else {
    false
  }
}

///|
/// 生成攻击/移动范围内的所有偏移量（曼哈顿距离）
///
/// 该函数用于生成指定范围内所有位置的偏移量，使用曼哈顿距离（Manhattan distance）
/// 计算。函数会生成所有距离中心点曼哈顿距离 <= range 且 != 0 的位置偏移量。
/// 这用于计算攻击范围、移动范围等，确保范围内的所有位置都被考虑。
///
/// 参数说明：
/// - range: 范围大小（格子数），表示曼哈顿距离的最大值
///
/// 返回值：
/// - 返回 Array[(Int, Int)] 类型，包含所有偏移量的数组
/// - 偏移量范围：从 (-range, -range) 到 (range, range)
/// - 不包括 (0, 0)（中心点本身）
///
/// 计算逻辑：
/// 1. 遍历所有可能的偏移量：i 从 -range 到 range，j 从 -range 到 range
/// 2. 对每个偏移量，计算曼哈顿距离：|i| + |j|
/// 3. 如果曼哈顿距离 <= range 且 != 0，将偏移量添加到结果数组
/// 4. 返回包含所有有效偏移量的数组
///
/// 使用场景：
/// - 计算攻击范围内的所有目标位置时
/// - 计算移动范围内的所有可移动位置时
/// - 需要生成范围内偏移量时
///
/// 注意事项：
/// - 使用曼哈顿距离（|x| + |y|），不是欧几里得距离
/// - 不包括中心点 (0, 0)
/// - 生成的偏移量可以用于计算目标位置：target = center + offset
fn generate_offset(range : Int) -> Array[(Int, Int)] {
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
/// 获取位置的所有可通行邻居（移动范围内的相邻位置）
///
/// 该函数用于获取指定位置在移动范围内的所有可通行邻居位置。函数会生成移动
/// 范围内的所有偏移量，然后检查每个邻居位置是否可通行，只返回可通行的位置。
/// 这用于A*路径查找算法，获取当前位置可以移动到的所有相邻位置。
///
/// 参数说明：
/// - path_finder_map: 路径查找地图实例
/// - range: 移动范围大小（格子数），表示单位可以移动的最大距离
/// - position: 当前位置的全局坐标 (x, y)
///
/// 返回值：
/// - 返回 Array[(Int, Int)] 类型，包含所有可通行邻居位置的数组
///
/// 执行流程：
/// 1. 生成移动范围内的所有偏移量（generate_offset(range)）
/// 2. 遍历所有偏移量，计算邻居位置：
///    a. 计算邻居位置 = 当前位置 + 偏移量
///    b. 检查邻居位置是否可通行（is_block_walkable）
///    c. 如果可通行，将邻居位置添加到结果数组
/// 3. 返回包含所有可通行邻居的数组
///
/// 使用场景：
/// - A*路径查找算法获取可移动邻居时
/// - 需要计算移动范围内的可通行位置时
///
/// 注意事项：
/// - 只返回可通行的位置，被占用的位置会被过滤
/// - 移动范围使用曼哈顿距离
/// - 邻居位置是相对于当前位置的偏移
fn PathFinderMap::get_walkable_neighbors(
  path_finder_map : PathFinderMap,
  range : Int,
  position : (Int, Int),
) -> Array[(Int, Int)] {
  let offset = generate_offset(range)
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
/// 路径节点结构体（A*算法的节点）
///
/// 该结构体表示A*路径查找算法中的一个节点，包含位置信息和路径成本。每个节点
/// 代表路径上的一个位置，用于计算从起点到终点的最优路径。
///
/// 字段说明：
/// - position: 节点的位置坐标 (x, y)
/// - g_cost: 从起点到当前节点的实际成本（可变的，在算法中会更新）
/// - h_cost: 从当前节点到终点的启发式估计成本（曼哈顿距离）
/// - f_cost: 节点的总成本 f = g + h（可变的，在算法中会更新）
priv struct PathNode {
  position : (Int, Int)
  mut g_cost : Int
  h_cost : Int
  mut f_cost : Int
}

///|
/// 计算两点之间的曼哈顿距离（启发式函数）
///
/// 该函数用于计算两个位置之间的曼哈顿距离（Manhattan distance），也称为
/// 城市街区距离或L1距离。曼哈顿距离是两点在网格地图上的最短路径距离，计算
/// 公式为 |x1 - x2| + |y1 - y2|。这用于A*算法的启发式函数，估计从当前位置
/// 到终点的距离。
///
/// 参数说明：
/// - pos1: 第一个位置的坐标 (x, y)
/// - pos2: 第二个位置的坐标 (x, y)
///
/// 返回值：
/// - 返回 Int 类型，表示两点之间的曼哈顿距离（格子数）
///
/// 计算公式：
/// - dx = |pos1.x - pos2.x|
/// - dy = |pos1.y - pos2.y|
/// - distance = dx + dy
///
/// 使用场景：
/// - A*路径查找算法计算启发式成本时
/// - 需要估算两点距离时
///
/// 注意事项：
/// - 曼哈顿距离适合网格地图，不适合对角线移动
/// - 距离是整数，表示格子数
/// - 用于A*算法的h_cost（启发式估计）
fn manhattan_distance(pos1 : (Int, Int), pos2 : (Int, Int)) -> Int {
  let dx = if pos1.0 > pos2.0 { pos1.0 - pos2.0 } else { pos2.0 - pos1.0 }
  let dy = if pos1.1 > pos2.1 { pos1.1 - pos2.1 } else { pos2.1 - pos1.1 }
  dx + dy
}

///|
/// 使用A*算法计算从起点到终点的下一步移动位置（路径查找核心函数）
///
/// 该函数实现了A*路径查找算法，用于计算单位从起点到终点的最优路径，并返回
/// 下一步应该移动到的位置。算法会考虑移动范围和攻击范围：如果单位可以在移动
/// 范围内到达攻击范围，算法会在攻击范围内停止，而不是必须到达终点。这用于
/// 敌人AI移动，让敌人移动到可以攻击目标的位置。
///
/// 参数说明：
/// - path_finder_map: 路径查找地图实例，包含可通行性信息
/// - start: 起点位置坐标 (x, y)
/// - end: 终点位置坐标 (x, y)（通常是目标位置）
/// - move_range: 单位的移动范围（格子数），限制单次移动的最大距离
/// - attack_range: 单位的攻击范围（格子数），如果到达攻击范围可以停止
///
/// 返回值：
/// - 返回 (Int, Int)? 类型（可选位置）
/// - Some(position): 找到可行路径，返回下一步移动位置
/// - None: 无法找到可行路径（被障碍物阻挡或超出移动范围）
///
/// 算法流程（A*路径查找）：
/// 1. 初始化：
///    a. 创建开放列表（open_list），包含起点节点
///    b. 创建关闭列表（closed_list），用于记录已访问的节点
///    c. 创建路径记录（came_from），用于回溯路径
/// 2. 主循环（当开放列表不为空时）：
///    a. 从开放列表中选择f_cost最小的节点作为当前节点
///    b. 将当前节点从开放列表移到关闭列表
///    c. 检查是否到达终点或进入攻击范围：
///       - 如果当前位置 == 终点，或距离终点 <= attack_range，回溯路径
///       - 从终点回溯到起点，返回第一步移动位置
///    d. 获取当前节点的所有可通行邻居（get_walkable_neighbors）
///    e. 对每个邻居节点：
///       - 如果已在关闭列表中，跳过
///       - 计算从起点到邻居的实际成本（tentative_g_cost = current.g_cost + 1）
///       - 如果邻居不在开放列表中，添加到开放列表
///       - 如果邻居在开放列表中但新路径更优，更新邻居的成本和父节点
/// 3. 如果开放列表为空仍未找到路径，返回 None
///
/// 特殊处理：
/// - 如果起点 == 终点，直接返回起点
/// - 如果到达攻击范围内（距离终点 <= attack_range），可以停止移动
/// - 移动范围限制单次移动的最大距离
///
/// 使用场景：
/// - 敌人AI计算移动路径时
/// - 需要计算单位移动路径时
///
/// 注意事项：
/// - 使用A*算法，保证找到最优路径（如果存在）
/// - 考虑移动范围和攻击范围，不一定需要到达终点
/// - 如果无法找到路径，返回 None
/// - 算法使用曼哈顿距离作为启发式函数
fn PathFinderMap::get_next_step(
  path_finder_map : PathFinderMap,
  start : (Int, Int),
  end : (Int, Int),
  move_range : Int,
  attack_range : Int,
) -> (Int, Int)? {
  if start == end {
    return Some(start)
  }
  let open_list = [
    PathNode::{
      position: start,
      g_cost: 0,
      h_cost: manhattan_distance(start, end),
      f_cost: manhattan_distance(start, end),
    },
  ]
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
    // 如果到达终点，或者当前位置在攻击范围内（可以攻击目标）
    let distance_to_end = manhattan_distance(current.position, end)
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
        let h_cost = manhattan_distance(neighbor, end)
        let f_cost = tentative_g_cost + h_cost
        open_list.push(PathNode::{
          position: neighbor,
          g_cost: tentative_g_cost,
          h_cost,
          f_cost,
        })
        came_from.set(neighbor, current.position)
      } else if tentative_g_cost < open_list[open_index].g_cost {
        open_list[open_index].g_cost = tentative_g_cost
        open_list[open_index].f_cost = tentative_g_cost +
          open_list[open_index].h_cost
        came_from.set(neighbor, current.position)
      }
    }
  }
  None
}
