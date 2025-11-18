///|
/// 房间结构体（游戏地图的基本单元）
///
/// 该结构体表示游戏地图上的一个房间，每个房间是一个9x9的网格，包含81个地图块。
/// 房间是游戏世界的基本单元，包含敌人、材料、建筑等内容。房间可以动态生成，
/// 当玩家移动到新区域时会创建新房间。
///
/// 字段说明：
/// - level: 房间等级（1-6），决定房间内敌人的等级和数量
/// - index_position: 房间在地图上的索引位置 (x, y)，表示房间左上角的全局坐标
/// - blocks: 房间内的地图块网格（9x9的二维数组），每个元素是一个 MapBlock
priv struct Room {
  level : Int
  index_position : (Int, Int)
  blocks : Array[Array[MapBlock]]
}

///|
/// 默认敌人数量数组（根据房间等级）
///
/// 该数组定义了不同等级房间的默认敌人数量。数组索引对应房间等级，值对应敌人数量。
/// 注意：等级0对应0个敌人（不使用），等级6是BOSS房间，敌人数量可能不同。
///
/// 数组内容：
/// - [0]: 等级0（不使用）
/// - [1]: 等级1房间，2个敌人
/// - [2]: 等级2房间，3个敌人
/// - [3]: 等级3房间，4个敌人
/// - [4]: 等级4房间，6个敌人
/// - [5]: 等级5房间，6个敌人
/// - [6]: 等级6房间，8个敌人（BOSS房间，但实际可能生成BOSS）
let default_enemy_count = [0, 2, 3, 4, 6, 6, 8]

///|
/// 根据房间等级随机生成敌人（敌人生成函数）
///
/// 该函数用于根据房间等级从敌人列表中随机选择一个敌人。函数会过滤出等级小于
/// 等于房间等级的所有敌人，然后从中随机选择一个。这确保房间内的敌人等级不会
/// 超过房间等级。
///
/// 参数说明：
/// - level: 房间等级（1-6）
///
/// 返回值：
/// - 返回 EnemyBase 类型，随机选择的敌人基础信息
///
/// 执行流程：
/// 1. 过滤敌人列表，只保留等级 <= level 的敌人（enemy_list.filter）
/// 2. 从过滤后的敌人列表中随机选择一个（使用 summon_random_number）
/// 3. 返回选择的敌人基础信息
///
/// 使用场景：
/// - 生成新房间时随机生成敌人
/// - 需要根据等级生成敌人时
///
/// 注意事项：
/// - 只生成等级不超过房间等级的敌人
/// - 如果过滤后列表为空，会导致数组越界错误
/// - 随机选择使用 summon_random_number 函数
fn summon_enemy(level : Int) -> EnemyBase {
  let can_summon_enemy = enemy_list.filter(enemy => enemy.level <= level)
  let enemy = can_summon_enemy[summon_random_number(
      0,
      can_summon_enemy.length() - 1,
    )]
  enemy
}

///|
/// 生成随机位置（排除指定位置集合）
///
/// 该函数用于在房间内（9x9网格）生成一个随机位置，同时排除 escape_set 中指定的
/// 位置。函数会不断生成随机位置，直到找到一个不在 escape_set 中的位置。这用于
/// 在生成房间内容时避免在特定位置放置单位（如避免在玩家起始位置放置敌人）。
///
/// 参数说明：
/// - escape_set: 需要排除的位置集合，这些位置不会用于生成单位
///
/// 返回值：
/// - 返回 (Int, Int) 类型，房间内的本地坐标 (x, y)，范围 0-8
///
/// 执行流程：
/// 1. 生成随机X坐标（0-8）和随机Y坐标（0-8）
/// 2. 检查位置是否在 escape_set 中
/// 3. 如果在 escape_set 中，重新生成随机位置
/// 4. 重复步骤1-3，直到找到不在 escape_set 中的位置
/// 5. 返回找到的位置
///
/// 使用场景：
/// - 生成房间时随机放置敌人
/// - 生成房间时随机放置材料
/// - 需要排除特定位置时
///
/// 注意事项：
/// - 位置范围是 0-8（9x9 房间）
/// - 如果 escape_set 包含所有位置，会导致无限循环
/// - 函数会不断重试，直到找到可用位置
fn sumoon_postion(escape_set : Set[(Int, Int)]) -> (Int, Int) {
  let mut random_position_x = summon_random_number(0, 8)
  let mut random_position_y = summon_random_number(0, 8)
  while escape_set.contains((random_position_x, random_position_y)) {
    random_position_x = summon_random_number(0, 8)
    random_position_y = summon_random_number(0, 8)
  }
  (random_position_x, random_position_y)
}

///|
/// 创建新的房间（生成房间内容）
///
/// 该函数用于创建一个新的房间，并生成房间内的所有内容（敌人、材料、建筑等）。
/// 函数会根据房间等级生成对应数量的敌人，随机放置材料，并在房间中心放置充能线圈。
/// 特殊地，如果房间等级为6且BOSS未生成，会生成两个BOSS；如果BOSS已生成，等级6
/// 房间会降级为等级5。
///
/// 参数说明：
/// - level: 房间等级（1-6），决定敌人等级和数量
/// - index_position: 房间在地图上的索引位置 (x, y)，表示房间左上角的全局坐标
/// - escape_set: 需要排除的位置集合，避免在这些位置放置单位
///
/// 返回值：
/// - 返回新创建的房间实例 Room
///
/// 执行流程：
/// 1. 创建9x9的地图块网格，每个地图块都是独立的（避免共享引用）
/// 2. 检查房间等级和BOSS生成状态：
///    a. 如果 level == 6 且 boss_borned.val == false:
///       - 在位置 (3, 4) 生成BOSS"废械吞噬者·饕餮"
///       - 在位置 (5, 4) 生成BOSS"织网夫人·夏特拉"
///       - 设置 boss_borned.val = true
///    b. 否则（普通房间）:
///       - 如果 level == 6，降级为 level = 5（避免重复生成BOSS）
///       - 在房间中心 (4, 4) 放置充能线圈（怪物生成器）
///       - 根据房间等级生成对应数量的敌人（default_enemy_count[level]）
///       - 每个敌人随机选择位置（使用 sumoon_postion，排除 escape_set）
///       - 将敌人位置添加到 escape_set，避免重复
///       - 40%概率生成精炼铜锭（RefinedCopperIngot）
///       - 40%概率生成谐振星晶（ResonantStarCrystal）
/// 3. 返回创建的房间实例
///
/// 使用场景：
/// - 生成新房间时
/// - 游戏开始时创建起始房间
///
/// 注意事项：
/// - 房间大小固定为9x9
/// - 每个地图块都是独立的，避免共享引用问题
/// - BOSS只在第一个等级6房间生成
/// - 材料生成概率为40%，可能同时生成两种材料
/// - escape_set 用于避免在特定位置放置单位
fn Room::new(
  level : Int,
  index_position : (Int, Int),
  escape_set : Set[(Int, Int)],
) -> Room {
  // 修复：创建完全独立的2D数组，避免共享引用
  let mut level = level
  let blocks = []
  for _ in 0..<9 {
    let row = []
    for _ in 0..<9 {
      row.push(MapBlock::new()) // 每个MapBlock都是独立的
    }
    blocks.push(row)
  }
  if level == 6 && boss_borned.val == false {
    // 左边的 BOSS
    blocks[3][4].occupant = Enemy(
      Enemy::new(
        enemy_info_map["（BOSS）废械吞噬者·饕餮"],
        (index_position.0 + 3, index_position.1 + 4),
        false,
      ),
    )
    // 右边的 BOSS
    blocks[5][4].occupant = Enemy(
      Enemy::new(
        enemy_info_map["（BOSS）织网夫人·夏特拉"],
        (index_position.0 + 5, index_position.1 + 4),
        false,
      ),
    )
    boss_borned.val = true
  } else {
    if level == 6 {
      level = 5
    }
    // 中心点设置为怪物生成器
    blocks[4][4].occupant = Structure(
      Structure::new(
        structure_info_map["充能线圈"],
        owned=false,
        resource_type=None,
        (index_position.0 + 4, index_position.1 + 4),
      ),
    )
    for i in 0..<default_enemy_count[level] {
      let enemy = summon_enemy(level)
      let position = sumoon_postion(escape_set)
      escape_set.add(position)
      // 将房间内的本地坐标转换为全局坐标
      let global_position = (
        index_position.0 + position.0,
        index_position.1 + position.1,
      )
      blocks[position.0][position.1].occupant = Enemy(
        Enemy::new(enemy, global_position, false),
      )
    }
    // 生成 RefinedCopperIngot
    if check_probability(0.4) {
      let position = sumoon_postion(escape_set)
      escape_set.add(position)
      blocks[position.0][position.1].occupant = Material(
        Material::new(refined_copper_ingot),
      )
    }
    // 生成 ResonantStarCrystal
    if check_probability(0.4) {
      let position = sumoon_postion(escape_set)
      escape_set.add(position)
      blocks[position.0][position.1].occupant = Material(
        Material::new(resonant_star_crystal),
      )
    }
  }
  { level, index_position, blocks }
}

///|
/// 检查房间是否已满（所有位置都被占用）
///
/// 该函数用于检查房间内是否所有位置都被占用（没有空位置）。函数会遍历房间内的
/// 所有地图块，如果发现任何一个空位置（Empty），返回 false；如果所有位置都被
/// 占用，返回 true。这用于判断房间是否可以继续生成新单位。
///
/// 参数说明：
/// - room: 要检查的房间实例
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 房间已满（所有位置都被占用）
/// - false: 房间未满（至少有一个空位置）
///
/// 执行流程：
/// 1. 遍历房间内的所有地图块（9x9 网格）
/// 2. 对每个地图块，检查占用者是否为 Empty
/// 3. 如果发现任何一个空位置，立即返回 false
/// 4. 如果遍历完所有地图块都没发现空位置，返回 true
///
/// 使用场景：
/// - 判断房间是否可以继续生成新单位时
/// - 充能线圈生成敌人前检查房间是否已满
///
/// 注意事项：
/// - 房间大小固定为9x9，共81个位置
/// - 只要有一个空位置就返回 false
/// - 用于防止在已满房间中生成新单位
fn Room::is_full(room : Room) -> Bool {
  for blocks in room.blocks {
    for block in blocks {
      if block.occupant is Empty {
        return false
      }
    }
  }
  true
}

///|
/// 获取房间内所有空位置（本地坐标）
///
/// 该函数用于获取房间内所有空位置（占用者为 Empty）的本地坐标。函数会遍历房间
/// 内的所有地图块，收集所有空位置的坐标，返回一个坐标数组。这用于在房间内随机
/// 选择空位置放置新单位。
///
/// 参数说明：
/// - room: 要获取空位置的房间实例
///
/// 返回值：
/// - 返回 Array[(Int, Int)] 类型，包含所有空位置的本地坐标数组
/// - 坐标范围是 0-8（9x9 房间）
///
/// 执行流程：
/// 1. 创建空的结果数组
/// 2. 遍历房间内的所有地图块（9x9 网格）
/// 3. 对每个地图块，检查占用者是否为 Empty
/// 4. 如果是空位置，将坐标添加到结果数组
/// 5. 返回包含所有空位置的数组
///
/// 使用场景：
/// - 充能线圈生成敌人时随机选择空位置
/// - 需要在房间内随机放置单位时
/// - 需要获取所有可用位置时
///
/// 注意事项：
/// - 返回的是房间内的本地坐标（0-8），不是全局坐标
/// - 如果房间已满，返回空数组
/// - 坐标可以直接用于访问 room.blocks[x][y]
fn Room::get_empty_positions(room : Room) -> Array[(Int, Int)] {
  let positions = []
  for block_x in 0..<9 {
    for block_y in 0..<9 {
      if room.blocks[block_x][block_y].occupant is Empty {
        positions.push((block_x, block_y))
      }
    }
  }
  positions
}

///|
/// 检查坐标是否在房间内（全局坐标判断）
///
/// 该函数用于检查指定的全局坐标是否在房间的范围内。函数会比较坐标与房间的
/// 索引位置和大小，判断坐标是否在房间的9x9网格内。这用于判断位置是否属于
/// 某个房间。
///
/// 参数说明：
/// - room: 要检查的房间实例
/// - coord: 全局坐标 (x, y)
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 坐标在房间内
/// - false: 坐标不在房间内
///
/// 判断逻辑：
/// - 计算坐标相对于房间左上角的偏移
/// - 检查 X 坐标：x >= room_x && x < room_x + 9
/// - 检查 Y 坐标：y >= room_y && y < room_y + 9
/// - 两个条件都满足时返回 true
///
/// 使用场景：
/// - 查找位置所在的房间时
/// - 判断位置是否在某个房间内时
/// - 需要验证坐标有效性时
///
/// 注意事项：
/// - 房间大小固定为9x9
/// - 坐标范围是 [room_x, room_x + 9) 和 [room_y, room_y + 9)
/// - 使用左闭右开区间，不包含右边界
fn Room::is_coord_in_room(room : Room, coord : (Int, Int)) -> Bool {
  let (x, y) = coord
  let (room_x, room_y) = room.index_position
  x >= room_x && x < room_x + 9 && y >= room_y && y < room_y + 9
}

///|
/// 根据坐标计算房间方向和相邻房间位置（用于房间生成）
///
/// 该函数用于根据坐标相对于房间的位置，计算相邻房间的方向和位置。当玩家移动到
/// 房间边界外时，需要生成新的相邻房间。函数会判断坐标在房间的哪个方向（上、下、
/// 左、右、左上、左下、右上、右下），并计算新房间的索引位置。
///
/// 参数说明：
/// - room: 当前房间实例
/// - coord: 目标全局坐标 (x, y)，应该在房间外
///
/// 返回值：
/// - 返回元组 (Direction, (Int, Int))
/// - Direction: 新房间相对于当前房间的方向（Left、Right、Up、Down等）
/// - (Int, Int): 新房间的索引位置 (x, y)
///
/// 计算逻辑：
/// 1. 计算坐标相对于房间左上角的偏移（relative_x, relative_y）
/// 2. 根据偏移判断方向：
///    a. 如果 relative_x < 0（在房间左侧）:
///       - 如果 relative_y < 0: 方向为 LeftDown，新位置 (room_x - 9, room_y)
///       - 如果 relative_y >= 9: 方向为 LeftUp，新位置 (room_x - 9, room_y + 9)
///       - 否则: 方向为 Left，新位置 (room_x - 9, room_y)
///    b. 如果 relative_x >= 9（在房间右侧）:
///       - 如果 relative_y < 0: 方向为 RightDown，新位置 (room_x + 9, room_y)
///       - 如果 relative_y >= 9: 方向为 RightUp，新位置 (room_x + 9, room_y + 9)
///       - 否则: 方向为 Right，新位置 (room_x + 9, room_y)
///    c. 如果 relative_y < 0（在房间上方）: 方向为 Down，新位置 (room_x, room_y - 9)
///    d. 否则（在房间下方）: 方向为 Up，新位置 (room_x, room_y + 9)
///
/// 使用场景：
/// - 玩家移动到房间边界外时生成新房间
/// - 需要计算相邻房间位置时
///
/// 注意事项：
/// - 房间大小固定为9x9
/// - 新房间位置与当前房间相邻，距离为9个格子
/// - 方向用于确定新房间的生成位置
/// - 支持8个方向（上、下、左、右、四个对角线）
fn Room::get_room_direction_and_new_position(
  room : Room,
  coord : (Int, Int),
) -> (Direction, (Int, Int)) {
  let (x, y) = coord
  let (room_x, room_y) = room.index_position
  let relative_x = x - room_x
  let relative_y = y - room_y
  if relative_x < 0 {
    if relative_y < 0 {
      (LeftDown, (room_x - 9, room_y))
    } else if relative_y >= 9 {
      (LeftUp, (room_x - 9, room_y + 9))
    } else {
      (Left, (room_x - 9, room_y))
    }
  } else if relative_x >= 9 {
    if relative_y < 0 {
      (RightDown, (room_x + 9, room_y))
    } else if relative_y >= 9 {
      (RightUp, (room_x + 9, room_y + 9))
    } else {
      (Right, (room_x + 9, room_y))
    }
  } else if relative_y < 0 {
    (Down, (room_x, room_y - 9))
  } else {
    (Up, (room_x, room_y + 9))
  }
}
