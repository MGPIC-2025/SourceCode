///|
/// 地图占用者枚举（表示地图块上的内容类型）
///
/// 该枚举定义了地图块上可以存在的所有内容类型。每个地图块（MapBlock）只能
/// 包含一种占用者，用于表示该位置上的单位或物品。这是地图系统的核心抽象。
///
/// 枚举值：
/// - Enemy(Enemy): 敌人单位（可以是野生敌人或友方召唤物）
/// - Copper(BattleCopper): 战斗铜偶（玩家控制的单位）
/// - Material(Material): 材料物品（可收集的资源）
/// - Structure(Structure): 建筑（玩家建造或房间生成的建筑）
/// - Empty: 空位置（没有占用者，可以移动或放置单位）
priv enum Occupant {
  Enemy(Enemy)
  Copper(BattleCopper)
  Material(Material)
  Structure(Structure)
  Empty
}

///|
/// 地图块结构体（地图的基本单元）
///
/// 该结构体表示地图上的一个基本单元（格子），每个地图块可以包含一个占用者
/// （单位或物品）。地图块是9x9房间网格的基本组成元素，用于管理单位的位置
/// 和占用情况。
///
/// 字段说明：
/// - occupant: 地图块上的占用者（可变的），可以是敌人、铜偶、材料、建筑或空
struct MapBlock {
  mut occupant : Occupant
}

///|
/// 创建新的空地图块
///
/// 该函数用于创建一个新的空地图块，初始状态为 Empty（没有占用者）。新创建
/// 的地图块可以用于构建房间的网格，或作为地图扩展的基础单元。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回新创建的地图块实例，occupant 为 Empty
///
/// 使用场景：
/// - 创建新房间时初始化地图块网格
/// - 需要创建空地图块时
///
/// 注意事项：
/// - 新创建的地图块是空的，需要手动设置占用者
/// - 地图块是房间网格的基本单元，通常以9x9的网格形式组织
pub fn MapBlock::new() -> MapBlock {
  { occupant: Empty }
}

///|
/// 地图结构体（游戏地图的容器）
///
/// 该结构体表示整个游戏地图，包含所有房间的集合。地图是游戏世界的容器，
/// 管理所有房间的位置、内容和状态。地图支持动态扩展，当玩家移动到新区域时
/// 会生成新房间。
///
/// 字段说明：
/// - rooms: 地图上所有房间的数组，每个房间是一个9x9的网格
priv struct Map_ {
  rooms : Array[Room]
}

///|
/// 创建新的游戏地图（初始化起始房间）
///
/// 该函数用于创建新的游戏地图，并初始化起始房间。函数会创建一个等级为1的
/// 起始房间，位置在 (0, 0)，并将其添加到地图中。注意：游戏初始化时不会
/// 立即广播房间内容，而是等放置铜偶后统一广播，避免重复消息。
///
/// 参数说明：
/// - escape_set: 需要排除的位置集合，用于在生成房间时避免在这些位置放置单位
///
/// 返回值：
/// - 返回新创建的地图实例，包含一个起始房间
///
/// 执行流程：
/// 1. 创建等级为1的起始房间，位置在 (0, 0)，使用 escape_set 排除位置
/// 2. 创建空的地图实例（rooms 为空数组）
/// 3. 使用 add_room_silent 将房间添加到地图（不立即广播）
/// 4. 返回创建的地图实例
///
/// 使用场景：
/// - 游戏开始时创建初始地图
/// - 需要创建新地图时
///
/// 注意事项：
/// - 起始房间等级固定为1
/// - 起始房间位置固定为 (0, 0)
/// - 房间内容不会立即广播，等放置铜偶后统一广播
/// - escape_set 用于避免在指定位置生成敌人或材料
fn Map_::new(escape_set : Set[(Int, Int)]) -> Map_ {
  let room = Room::new(1, (0, 0), escape_set)
  let map = Map_::{ rooms: [] }
  // 游戏初始化时不立即广播，等放置铜偶后统一广播
  Map_::add_room(map, room)
  map
}

///|
/// 强制获取指定位置的地图块（不安全操作）
///
/// 该函数用于获取指定全局位置的地图块。函数使用 guard 语句强制解包，如果
/// 位置不在任何房间内或无法转换为房间本地坐标，会导致程序崩溃。因此函数名
/// 使用 "force" 前缀表示这是一个不安全的操作。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回指定位置的地图块实例
/// - 如果位置不在任何房间内，会触发 panic
///
/// 使用场景：
/// - 需要直接访问地图块时（确保位置有效）
/// - 需要修改地图块内容时
///
/// 注意事项：
/// - 函数使用 guard 强制解包，如果位置无效会导致程序崩溃
/// - 确保在调用此函数前位置已经在某个房间内
/// - 建议在调用前使用 find_position_in_map 检查位置有效性
fn Map_::force_get_map_block(map : Map_, position : (Int, Int)) -> MapBlock {
  let room = Map_::find_position_in_map(map, position)
  guard room is Some(room)
  guard map.global_position_to_room_position(position) is Some((_, position))
  room.blocks[position.0][position.1]
}

///|
/// 检查位置是否被占用或在地图外（用于移动范围判断）
///
/// 该函数用于检查指定位置是否被占用或在地图外。如果位置在房间内且被占用，
/// 返回 true；如果位置不在任何房间内（地图外），也返回 true；只有位置在
/// 房间内且为空时，返回 false。这个函数用于判断单位是否可以移动到该位置。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 要检查的全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 位置被占用或在地图外（不可移动）
/// - false: 位置在房间内且为空（可以移动）
///
/// 使用场景：
/// - 计算单位的可移动范围时
/// - 判断位置是否可用时
///
/// 注意事项：
/// - 地图外的位置被视为不可移动（返回 true）
/// - 只有房间内且为空的位置才可移动（返回 false）
/// - 与 is_occupy 的区别：地图外位置返回 true 而不是 false
fn Map_::is_occupy_or_out_of_map(map : Map_, position : (Int, Int)) -> Bool {
  let room = Map_::find_position_in_map(map, position)
  if room is Some(room) {
    guard map.global_position_to_room_position(position) is Some((_, position))
    return !(room.blocks[position.0][position.1].occupant is Empty)
  }
  true
}

///|
/// 检查位置是否被占用（仅检查房间内的位置）
///
/// 该函数用于检查指定位置是否被占用。如果位置在房间内且被占用，返回 true；
/// 如果位置在房间内且为空，返回 false；如果位置不在任何房间内（地图外），
/// 返回 false。这个函数用于判断位置是否有占用者，不考虑地图边界。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 要检查的全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 位置在房间内且被占用
/// - false: 位置在房间内且为空，或位置不在任何房间内
///
/// 使用场景：
/// - 检查位置是否有占用者时
/// - 判断是否可以放置单位时
///
/// 注意事项：
/// - 地图外的位置被视为未占用（返回 false）
/// - 只有房间内且被占用的位置才返回 true
/// - 与 is_occupy_or_out_of_map 的区别：地图外位置返回 false 而不是 true
fn Map_::is_occupy(map : Map_, position : (Int, Int)) -> Bool {
  let room = Map_::find_position_in_map(map, position)
  if room is Some(room) {
    guard map.global_position_to_room_position(position) is Some((_, position))
    return !(room.blocks[position.0][position.1].occupant is Empty)
  }
  false
}

///|
/// 计算位置到最近房间边界的最短距离（切比雪夫距离）
///
/// 该函数用于计算指定位置到最近房间边界的最短距离。如果位置在某个房间内，
/// 返回 0；如果位置在所有房间外，计算到最近房间边界的距离，使用切比雪夫距离
/// （棋盘距离，即 max(dx, dy)）。这个函数用于判断单位距离房间的远近，影响
/// 移动范围的计算。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 要计算距离的全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Int 类型，表示到最近房间边界的距离
/// - 0: 位置在某个房间内
/// - >0: 位置在所有房间外，返回到最近房间边界的格子数
///
/// 计算逻辑：
/// 1. 如果位置在某个房间内，直接返回 0
/// 2. 遍历所有房间，计算到每个房间边界的距离
/// 3. 对于每个房间，计算 X 方向和 Y 方向的距离：
///    - 如果位置在房间左侧：dx = room_x - x
///    - 如果位置在房间右侧：dx = x - (room_x + 9) + 1
///    - 如果位置在房间范围内：dx = 0
///    - Y 方向同理
/// 4. 使用切比雪夫距离：distance = max(dx, dy)
/// 5. 返回所有房间中的最小距离
///
/// 使用场景：
/// - 计算单位的移动范围时（考虑距离房间的距离）
/// - 判断位置是否接近房间时
///
/// 注意事项：
/// - 使用切比雪夫距离（棋盘距离），适合网格地图
/// - 房间大小固定为 9x9
/// - 如果位置在房间内，距离为 0
/// - 距离计算用于限制单位的移动范围
fn Map_::distance_to_nearest_room(map : Map_, position : (Int, Int)) -> Int {
  // 如果在某个房间内，距离为0
  if Map_::find_position_in_map(map, position) is Some(_) {
    return 0
  }

  // 找到距离最近的房间
  let mut min_distance = 999999
  for room in map.rooms {
    let (room_x, room_y) = room.index_position
    let (x, y) = position

    // 计算到房间边界的最短距离
    let dx = if x < room_x {
      room_x - x
    } else if x >= room_x + 9 {
      x - (room_x + 9) + 1
    } else {
      0
    }
    let dy = if y < room_y {
      room_y - y
    } else if y >= room_y + 9 {
      y - (room_y + 9) + 1
    } else {
      0
    }

    // 使用切比雪夫距离（棋盘距离）
    let distance = if dx > dy { dx } else { dy }
    if distance < min_distance {
      min_distance = distance
    }
  }
  min_distance
}

///|
/// 强制获取位置所在的房间和本地坐标（不安全操作）
///
/// 该函数用于获取指定全局位置所在的房间和该位置在房间内的本地坐标。函数使用
/// guard 语句强制解包，如果位置不在任何房间内或无法转换为房间本地坐标，会导致
/// 程序崩溃。因此函数名使用 "force" 前缀表示这是一个不安全的操作。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回元组 (Room, (Int, Int))
/// - Room: 位置所在的房间实例
/// - (Int, Int): 位置在房间内的本地坐标 (x, y)，范围 0-8
/// - 如果位置不在任何房间内，会触发 panic
///
/// 使用场景：
/// - 需要访问房间和本地坐标时（确保位置有效）
/// - 需要修改房间内地图块时
///
/// 注意事项：
/// - 函数使用 guard 强制解包，如果位置无效会导致程序崩溃
/// - 确保在调用此函数前位置已经在某个房间内
/// - 本地坐标范围是 0-8（9x9 房间）
/// - 建议在调用前使用 find_position_in_map 检查位置有效性
fn Map_::force_get_room_position(
  map : Map_,
  position : (Int, Int),
) -> (Room, (Int, Int)) {
  let room = Map_::find_position_in_map(map, position)
  guard room is Some(room)
  guard map.global_position_to_room_position(position) is Some((_, position))
  return (room, position)
}

///|
/// 获取指定位置的占用者（安全操作）
///
/// 该函数用于获取指定全局位置的占用者。函数会查找位置所在的房间，然后返回
/// 该位置地图块上的占用者。如果位置不在任何房间内，会触发 panic（因为使用了
/// force_get_room_position）。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Occupant 枚举值，表示该位置的占用者
/// - 可以是 Enemy、Copper、Material、Structure 或 Empty
/// - 如果位置不在任何房间内，会触发 panic
///
/// 使用场景：
/// - 检查位置上的单位或物品时
/// - 获取目标位置的内容时
/// - 判断位置是否可用时
///
/// 注意事项：
/// - 函数内部使用 force_get_room_position，位置无效会崩溃
/// - 返回的占用者可能是 Empty（空位置）
/// - 需要根据占用者类型进行模式匹配处理
fn Map_::get_occupant(map : Map_, position : (Int, Int)) -> Occupant {
  let (room, position) = Map_::force_get_room_position(map, position)
  return room.blocks[position.0][position.1].occupant
}

///|
/// 移除指定位置的占用者（清空地图块）
///
/// 该函数用于移除指定全局位置的占用者，将地图块设置为 Empty。函数会查找
/// 位置所在的房间，然后将该位置的地图块设置为空。这通常用于单位移动或
/// 被移除时。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 获取位置所在的房间和本地坐标（force_get_room_position）
/// 2. 将房间内对应位置的地图块设置为 Empty
///
/// 使用场景：
/// - 单位移动时清除旧位置
/// - 单位被移除时清除位置
/// - 需要清空地图块时
///
/// 注意事项：
/// - 函数内部使用 force_get_room_position，位置无效会崩溃
/// - 移除后位置变为 Empty，可以放置新单位
/// - 确保在移除前已经处理了占用者的其他逻辑（如从集合中移除）
fn Map_::remove_occupant(map : Map_, position : (Int, Int)) -> Unit {
  let (room, position) = Map_::force_get_room_position(map, position)
  room.blocks[position.0][position.1].occupant = Empty
}

///|
/// 在指定位置添加占用者（设置地图块内容）
///
/// 该函数用于在指定全局位置添加占用者，将地图块设置为指定的占用者。函数会
/// 查找位置所在的房间，然后将该位置的地图块设置为指定的占用者。这通常用于
/// 放置单位或物品到地图上。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
/// - occupant: 要添加的占用者（Enemy、Copper、Material、Structure 或 Empty）
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 获取位置所在的房间和本地坐标（force_get_room_position）
/// 2. 将房间内对应位置的地图块设置为指定的占用者
///
/// 使用场景：
/// - 单位移动到新位置时
/// - 生成新单位时放置到地图
/// - 放置材料或建筑时
///
/// 注意事项：
/// - 函数内部使用 force_get_room_position，位置无效会崩溃
/// - 如果位置已有占用者，会被覆盖（确保先调用 remove_occupant）
/// - 添加后需要调用对应的 set_* 函数通知前端显示
fn Map_::add_occupant(
  map : Map_,
  position : (Int, Int),
  occupant : Occupant,
) -> Unit {
  let (room, position) = Map_::force_get_room_position(map, position)
  room.blocks[position.0][position.1].occupant = occupant
}

///|
/// 查找位置所在的房间（安全操作）
///
/// 该函数用于查找指定全局位置所在的房间。函数会遍历地图上的所有房间，检查
/// 位置是否在某个房间内。如果找到，返回该房间；如果位置不在任何房间内，返回
/// None。这是一个安全操作，不会导致程序崩溃。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Room? 类型（可选房间）
/// - Some(room): 位置在某个房间内，返回该房间
/// - None: 位置不在任何房间内（地图外）
///
/// 执行流程：
/// 1. 遍历地图上的所有房间
/// 2. 对每个房间，使用 Room::is_coord_in_room 检查位置是否在房间内
/// 3. 如果找到，立即返回该房间（Some(room)）
/// 4. 如果遍历完所有房间都没找到，返回 None
///
/// 使用场景：
/// - 检查位置是否在地图内时
/// - 需要获取位置所在的房间时
/// - 判断位置是否有效时
///
/// 注意事项：
/// - 这是一个安全操作，不会导致程序崩溃
/// - 返回可选类型，需要模式匹配处理
/// - 如果位置在多个房间内（理论上不应该发生），返回第一个找到的房间
fn Map_::find_position_in_map(map : Map_, position : (Int, Int)) -> Room? {
  for room in map.rooms {
    if Room::is_coord_in_room(room, position) {
      return Some(room)
    }
  }
  None
}

///|
/// 将全局坐标转换为房间本地坐标（安全操作）
///
/// 该函数用于将全局坐标转换为房间本地坐标。函数会查找位置所在的房间，然后
/// 计算该位置在房间内的本地坐标（相对于房间左上角的偏移）。如果位置不在任何
/// 房间内，返回 None。这是一个安全操作，不会导致程序崩溃。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - position: 全局位置坐标 (x, y)
///
/// 返回值：
/// - 返回 (Room, (Int, Int))? 类型（可选元组）
/// - Some((room, (local_x, local_y))): 位置在某个房间内
///   - room: 位置所在的房间实例
///   - (local_x, local_y): 位置在房间内的本地坐标，范围 0-8
/// - None: 位置不在任何房间内（地图外）
///
/// 执行流程：
/// 1. 遍历地图上的所有房间
/// 2. 对每个房间，使用 Room::is_coord_in_room 检查位置是否在房间内
/// 3. 如果找到，计算本地坐标：
///    - local_x = position.0 - room.index_position.0
///    - local_y = position.1 - room.index_position.1
/// 4. 返回房间和本地坐标（Some((room, (local_x, local_y)))）
/// 5. 如果遍历完所有房间都没找到，返回 None
///
/// 使用场景：
/// - 需要访问房间内地图块时
/// - 需要将全局坐标转换为本地坐标时
/// - 需要同时获取房间和本地坐标时
///
/// 注意事项：
/// - 这是一个安全操作，不会导致程序崩溃
/// - 返回可选类型，需要模式匹配处理
/// - 本地坐标范围是 0-8（9x9 房间）
/// - 如果位置在多个房间内（理论上不应该发生），返回第一个找到的房间
fn Map_::global_position_to_room_position(
  map : Map_,
  position : (Int, Int),
) -> (Room, (Int, Int))? {
  for room in map.rooms {
    if Room::is_coord_in_room(room, position) {
      // 转换为房间内的本地坐标
      let local_x = position.0 - room.index_position.0
      let local_y = position.1 - room.index_position.1
      return Some((room, (local_x, local_y)))
    }
  }
  None
}

///|
/// 广播房间内容到前端（优化版本，批量发送地图块）
///
/// 该函数用于将房间的所有内容（地图块、敌人、铜偶、材料、建筑等）广播到前端。
/// 函数会优化性能，使用批量发送地图块（put_room_blocks）避免发送225条单独消息
/// 造成卡顿，然后只发送有内容的格子（非空位置）。这是房间生成或显示时的核心函数。
///
/// 参数说明：
/// - room: 要广播的房间实例
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 获取房间的索引位置（room.index_position）
/// 2. 批量发送地图块：调用 put_room_blocks 一次性创建整个房间的地板（9x9）
/// 3. 遍历房间内的所有地图块（9x9 网格）：
///    a. 计算全局坐标（房间坐标 + 本地坐标）
///    b. 获取地图块上的占用者
///    c. 根据占用者类型发送对应的消息：
///       - Empty: 跳过（不发送）
///       - Enemy: 调用 set_enemy 并更新血量显示
///       - Copper: 调用 set_copper 并更新血量显示
///       - Structure: 调用 set_structure
///       - Material: 调用 set_material
///
/// 优化说明：
/// - 使用 put_room_blocks 批量发送地图块，避免225条单独消息
/// - 只发送有内容的格子，空位置不发送
/// - 敌人和铜偶会自动显示血条（update_health）
///
/// 使用场景：
/// - 生成新房间时广播房间内容
/// - 游戏开始时广播起始房间
/// - 需要显示房间内容时
///
/// 注意事项：
/// - 批量发送地图块可以显著提升性能
/// - 只发送有内容的格子，减少消息数量
/// - 敌人和铜偶会自动显示血条
/// - 确保在房间生成完成后调用
fn broadcast_room_content(room : Room) -> Unit {
  let (room_x, room_y) = room.index_position

  // 优化：批量发送地图块，避免225条单独消息造成卡顿
  put_room_blocks(room.index_position, 9)

  // 只发送有内容的格子（敌人、铜偶、矿物、建筑等）
  for x in 0..<9 {
    for y in 0..<9 {
      let global_pos = (room_x + x, room_y + y)
      let occupant = room.blocks[x][y].occupant
      match occupant {
        Empty => ()
        Enemy(enemy) => {
          set_enemy(enemy, enemy.id, global_pos)
          // 显示敌人血条
          update_health(enemy.id, enemy.now_health, enemy.enemy_base.health)
        }
        Copper(copper) => {
          set_copper(copper, copper.id, global_pos)
          // 显示铜偶血条
          update_health(
            copper.id,
            copper.now_health,
            copper.copper.attribute.health,
          )
        }
        Structure(structure) =>
          set_structure(structure, structure.id, global_pos)
        Material(material) => set_material(material, material.id, global_pos)
      }
    }
  }
}

///|
/// 将房间添加到地图（内部函数）
///
/// 该函数用于将新房间添加到地图的 rooms 数组中。函数会将房间添加到数组末尾，
/// 使房间成为地图的一部分。这是地图扩展的核心函数，用于动态添加新房间。
///
/// 参数说明：
/// - map: 当前游戏地图实例
/// - room: 要添加的房间实例
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 将房间添加到地图的 rooms 数组末尾（push）
///
/// 使用场景：
/// - 生成新房间时添加到地图
/// - 需要扩展地图时
///
/// 注意事项：
/// - 房间添加后立即成为地图的一部分
/// - 添加后需要调用 broadcast_room_content 广播房间内容
/// - 房间的索引位置应该不与现有房间重叠
fn Map_::add_room(map : Map_, room : Room) -> Unit {
  map.rooms.push(room)
}

///|
/// 获取全局地图（所有房间的地图块映射）
///
/// 该函数用于将地图上所有房间的地图块转换为全局坐标映射。函数会遍历所有房间，
/// 将每个房间内的地图块（使用本地坐标）转换为全局坐标（房间坐标 + 本地坐标），
/// 并构建一个全局坐标到地图块的映射。这用于路径查找等需要全局视图的操作。
///
/// 参数说明：
/// - map: 当前游戏地图实例
///
/// 返回值：
/// - 返回 Map[(Int, Int), MapBlock] 类型
/// - 键：全局位置坐标 (x, y)
/// - 值：该位置的地图块实例
///
/// 执行流程：
/// 1. 创建空的映射结果（Map）
/// 2. 遍历地图上的所有房间
/// 3. 对每个房间：
///    a. 获取房间的索引位置（room.index_position）
///    b. 遍历房间内的所有地图块（9x9 网格）
///    c. 计算全局坐标：global_pos = (room_x + x, room_y + y)
///    d. 将全局坐标和地图块添加到映射中
/// 4. 返回构建的全局映射
///
/// 使用场景：
/// - 路径查找算法需要全局地图视图时
/// - 需要遍历所有地图块时
/// - 需要全局坐标到地图块的快速查找时
///
/// 注意事项：
/// - 返回的映射包含所有房间的所有地图块
/// - 全局坐标是唯一的，不会重复
/// - 映射用于路径查找等算法，提供全局视图
/// - 如果房间重叠（理论上不应该发生），后面的房间会覆盖前面的
fn Map_::get_global_map(map : Map_) -> Map[(Int, Int), MapBlock] {
  let result = {}
  for room in map.rooms {
    let (room_x, room_y) = room.index_position
    for x in 0..<9 {
      for y in 0..<9 {
        let global_pos = (room_x + x, room_y + y)
        result[global_pos] = room.blocks[x][y]
      }
    }
  }
  result
}
