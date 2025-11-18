///|
/// 全局状态结构体（游戏的全局数据容器）
///
/// 该结构体存储游戏的全局状态，包括玩家的铜偶仓库和资源背包。这是游戏的核心
/// 数据容器，管理玩家在游戏外的所有资产（铜偶、资源等）。全局状态在游戏开始前
/// 和游戏结束后都会使用，是玩家进度和资产的持久化存储。
///
/// 字段说明：
/// - warehouse: 玩家的铜偶仓库（可变的），存储所有拥有的铜偶
/// - bag: 玩家的资源背包，存储所有拥有的资源
pub struct Global {
  mut warehouse : @warehouse.Warehouse
  bag : @global_resource.Bag
}

///|
/// 创建新的全局状态（初始化空仓库和背包）
///
/// 该函数用于创建一个新的全局状态实例，初始化空的铜偶仓库和资源背包。这通常
/// 用于游戏首次启动时，创建一个全新的玩家状态。新创建的全局状态不包含任何
/// 铜偶和资源，玩家需要通过游戏获得。
///
/// 参数说明：
/// - 无参数
///
/// 返回值：
/// - 返回新创建的 Global 实例，包含空的仓库和背包
///
/// 执行流程：
/// 1. 创建新的资源背包（@global_resource.Bag::new）
/// 2. 创建新的铜偶仓库（@warehouse.Warehouse::new）
/// 3. 返回包含新仓库和背包的 Global 实例
///
/// 使用场景：
/// - 游戏首次启动时创建初始状态
/// - 需要重置玩家状态时
///
/// 注意事项：
/// - 新创建的全局状态是空的，不包含任何铜偶和资源
/// - 仓库和背包都是新创建的，没有历史数据
pub fn Global::new() -> Global {
  { bag: @global_resource.Bag::new(), warehouse: @warehouse.Warehouse::new() }
}

///|
/// 从现有数据创建全局状态（用于加载存档）
///
/// 该函数用于从现有的仓库和背包数据创建全局状态实例。这通常用于加载游戏存档
/// 时，从保存的数据中恢复玩家的仓库和背包状态。函数会直接使用传入的仓库和
/// 背包，不创建新的实例。
///
/// 参数说明：
/// - warehouse: 现有的铜偶仓库实例
/// - bag: 现有的资源背包实例
///
/// 返回值：
/// - 返回包含传入仓库和背包的 Global 实例
///
/// 执行流程：
/// 1. 使用传入的 warehouse 和 bag 创建 Global 实例
/// 2. 返回创建的实例
///
/// 使用场景：
/// - 加载游戏存档时恢复玩家状态
/// - 从外部数据创建全局状态时
///
/// 注意事项：
/// - 直接使用传入的仓库和背包，不创建新实例
/// - 确保传入的仓库和背包数据有效
pub fn Global::from_existing(
  warehouse : @warehouse.Warehouse,
  bag : @global_resource.Bag,
) -> Global {
  { warehouse, bag }
}

///|
/// 获取所有资源数据（序列化为JSON字符串）
///
/// 该函数用于获取全局状态中所有资源的数量，并将数据序列化为JSON字符串返回。
/// 函数会查询资源背包中的所有资源类型，包括灵源火花、召回齿轮、谐振星晶、
/// 精炼铜和心晶粉尘。这用于前端显示玩家的资源状态。
///
/// 参数说明：
/// - global: 全局状态实例
///
/// 返回值：
/// - 返回 String 类型，包含所有资源数据的JSON字符串
/// - JSON格式：{"SpiritalSpark": 数量, "RecallGear": 数量, ...}
///
/// 资源类型：
/// - SpiritalSpark: 灵源火花
/// - RecallGear: 召回齿轮
/// - ResonantCrystal: 谐振星晶
/// - RefinedCopper: 精炼铜
/// - HeartCrystalDust: 心晶粉尘
///
/// 使用场景：
/// - 前端需要显示玩家资源时
/// - 需要获取资源数据时
///
/// 注意事项：
/// - 返回的是JSON字符串，前端需要解析
/// - 包含所有资源类型，即使数量为0也会包含
/// - 资源数量从资源背包中获取
pub fn Global::get_resource(global : Global) -> String {
  let resource = global.bag.resources
  (
    {
      "SpiritalSpark": resource.get_resource(@resource.SpiritalSpark),
      "RecallGear": resource.get_resource(@resource.RecallGear),
      "ResonantCrystal": resource.get_resource(@resource.ResonantCrystal),
      "RefinedCopper": resource.get_resource(@resource.RefinedCopper),
      "HeartCrystalDust": resource.get_resource(@resource.HeartCrystalDust),
    } : Json).stringify()
}

///|
/// 获取资源背包数据（序列化为JSON字符串）
///
/// 该函数用于获取全局状态中资源背包的完整数据，并将数据序列化为JSON字符串
/// 返回。函数会获取背包的所有信息，包括资源、物品等。这用于前端显示玩家的
/// 完整背包状态。
///
/// 参数说明：
/// - global: 全局状态实例
///
/// 返回值：
/// - 返回 String 类型，包含资源背包完整数据的JSON字符串
///
/// 使用场景：
/// - 前端需要显示完整背包时
/// - 需要获取背包数据时
///
/// 注意事项：
/// - 返回的是JSON字符串，前端需要解析
/// - 包含背包的所有数据，不仅仅是资源
/// - 使用背包的 to_json() 方法序列化
pub fn Global::get_bag(global : Global) -> String {
  global.bag.to_json().stringify()
}

///|
/// 获取铜偶列表（序列化为JSON字符串）
///
/// 该函数用于获取全局状态中铜偶仓库的所有铜偶列表，并将数据序列化为JSON字符串
/// 返回。函数会从仓库中获取所有铜偶，包括它们的属性、等级、装备等信息。这用于
/// 前端显示玩家的铜偶收藏。
///
/// 参数说明：
/// - global: 全局状态实例
///
/// 返回值：
/// - 返回 String 类型，包含铜偶列表的JSON字符串
/// - JSON格式：{"coppers": [铜偶数组]}
///
/// 使用场景：
/// - 前端需要显示铜偶列表时
/// - 需要获取所有铜偶数据时
///
/// 注意事项：
/// - 返回的是JSON字符串，前端需要解析
/// - 包含仓库中的所有铜偶
/// - 铜偶数据会被完整序列化，包括所有属性
pub fn Global::get_copper_list(global : Global) -> String {
  let warehouse = global.warehouse
  ({ "coppers": warehouse.get_copper_list().to_json() } : Json).stringify()
}

///|
/// 执行抽卡操作（消耗资源获得新铜偶）
///
/// 该函数用于执行抽卡操作，消耗资源从卡池中随机获得一个新铜偶。函数会检查
/// 资源是否充足，如果充足则消耗资源并添加新铜偶到仓库；如果资源不足，返回
/// 错误信息。这是玩家获得新铜偶的主要方式。
///
/// 参数说明：
/// - global: 全局状态实例（可变的，会修改仓库）
///
/// 返回值：
/// - 返回 String 类型，包含操作结果的JSON字符串
/// - 成功：{"type": "success", "copper": 铜偶数据}
/// - 失败：{"type": "error", "content": "资源不足"}
///
/// 执行流程：
/// 1. 调用抽卡函数（@warehouse.gacha），传入资源背包
/// 2. 检查抽卡结果：
///    a. 如果成功（返回 Some(copper)）:
///       - 将新铜偶添加到仓库（warehouse.add_copper）
///       - 更新全局状态的仓库
///       - 返回成功消息和铜偶数据
///    b. 如果失败（返回 None，资源不足）:
///       - 返回错误消息
///
/// 使用场景：
/// - 玩家点击抽卡按钮时
/// - 需要获得新铜偶时
///
/// 注意事项：
/// - 抽卡会消耗资源，必须确保资源充足
/// - 新铜偶会立即添加到仓库
/// - 如果资源不足，不会消耗资源也不会获得铜偶
/// - 返回的JSON需要前端解析并显示结果
pub fn Global::gacha(global : Global) -> String {
  let copper = @warehouse.gacha(global.bag.resources)
  (
    if copper is Some(copper) {
      global.warehouse = global.warehouse.add_copper(copper)
      { "type": "success", "copper": copper }
    } else {
      { "type": "error", "content": "资源不足" }
    } : Json).stringify()
}

///|
/// 升级指定铜偶（消耗资源提升铜偶等级）
///
/// 该函数用于升级指定ID的铜偶，消耗资源提升铜偶的等级。函数会检查资源是否
/// 充足，如果充足则消耗资源并升级铜偶；如果资源不足，返回错误信息。升级后
/// 的铜偶会替换仓库中的原铜偶。
///
/// 参数说明：
/// - global: 全局状态实例（可变的，会修改仓库和资源）
/// - id: 要升级的铜偶的唯一标识符
///
/// 返回值：
/// - 返回 String 类型，包含操作结果的JSON字符串
/// - 成功：{"type": "success"}
/// - 失败：{"type": "error", "content": "资源不足"}
///
/// 执行流程：
/// 1. 从仓库获取指定ID的铜偶（warehouse.get_copper）
/// 2. 计算升级所需的资源消耗（@coppers.get_upgrade_cost，根据铜偶等级）
/// 3. 检查资源是否充足（check_resource_cost）
/// 4. 如果资源充足：
///    a. 应用升级（copper.apply_upgrade），获得升级后的铜偶
///    b. 消耗资源（consume_resource_cost）
///    c. 从仓库移除原铜偶（warehouse.remove_copper）
///    d. 将升级后的铜偶添加到仓库（warehouse.add_copper）
///    e. 更新全局状态的仓库
///    f. 返回成功消息
/// 5. 如果资源不足：
///    a. 返回错误消息
///
/// 使用场景：
/// - 玩家点击升级按钮时
/// - 需要提升铜偶等级时
///
/// 注意事项：
/// - 升级会消耗资源，必须确保资源充足
/// - 升级后的铜偶会替换原铜偶（相同ID）
/// - 升级成本根据铜偶当前等级计算
/// - 如果资源不足，不会消耗资源也不会升级铜偶
pub fn Global::upgrade_copper(global : Global, id : Int) -> String {
  let warehouse = global.warehouse
  let copper = warehouse.get_copper(id)
  let upgrade_cost = @coppers.get_upgrade_cost(copper.level)
  (
    if @global_resource.GlobalResource::check_resource_cost(
        global.bag.resources,
        upgrade_cost,
      ) {
      let upgraded_copper = copper.apply_upgrade()
      @global_resource.GlobalResource::consume_resource_cost(
        global.bag.resources,
        upgrade_cost,
      )
      global.warehouse = global.warehouse.remove_copper(id)
      global.warehouse = global.warehouse.add_copper(upgraded_copper)
      { "type": "success" }
    } else {
      { "type": "error", "content": "资源不足" }
    } : Json).stringify()
}

///|
/// 合成灵源火花（消耗多种资源合成高级资源）
///
/// 该函数用于执行资源合成操作，消耗多种基础资源合成一个高级资源（灵源火花）。
/// 合成需要消耗：1个精炼铜、1个谐振星晶、1个心晶粉尘、1个召回齿轮。函数会
/// 检查资源是否充足，如果充足则消耗资源并添加灵源火花；如果资源不足，返回
/// 错误信息。
///
/// 参数说明：
/// - global: 全局状态实例（可变的，会修改资源背包）
///
/// 返回值：
/// - 返回 String 类型，包含操作结果的JSON字符串
/// - 成功：{"type": "success"}
/// - 失败：{"type": "error", "content": "资源不足"}
///
/// 合成配方：
/// - 精炼铜（RefinedCopper）: 1个
/// - 谐振星晶（ResonantCrystal）: 1个
/// - 心晶粉尘（HeartCrystalDust）: 1个
/// - 召回齿轮（RecallGear）: 1个
/// - 产出：灵源火花（SpiritalSpark）: 1个
///
/// 执行流程：
/// 1. 构造合成所需的资源消耗（ResourceCost::new）
/// 2. 检查资源是否充足（check_resource_cost）
/// 3. 如果资源充足：
///    a. 消耗资源（consume_resource_cost）
///    b. 添加1个灵源火花到资源背包（add_resource）
///    c. 返回成功消息
/// 4. 如果资源不足：
///    a. 返回错误消息
///
/// 使用场景：
/// - 玩家点击合成按钮时
/// - 需要获得灵源火花时
///
/// 注意事项：
/// - 合成会消耗多种资源，必须确保所有资源都充足
/// - 合成比例是1:1:1:1 -> 1（四种资源各1个合成1个灵源火花）
/// - 如果资源不足，不会消耗资源也不会获得灵源火花
/// - 灵源火花是高级资源，用于高级建造和召唤
pub fn Global::craft(global : Global) -> String {
  let cost = @resource.ResourceCost::new([
    (@resource.RefinedCopper, 1),
    (@resource.ResonantCrystal, 1),
    (@resource.HeartCrystalDust, 1),
    (@resource.RecallGear, 1),
  ])
  (
    if global.bag.resources.check_resource_cost(cost) {
      global.bag.resources.consume_resource_cost(cost)
      global.bag.resources.add_resource(@resource.SpiritalSpark, 1)
      { "type": "success" }
    } else {
      { "type": "error", "content": "资源不足" }
    } : Json).stringify()
}

///|
/// 全局状态引用（游戏的全局状态容器）
///
/// 该变量存储游戏的全局状态实例，使用 Ref 类型允许在函数间共享和修改全局状态。
/// 全局状态在游戏启动时初始化，包含玩家的铜偶仓库和资源背包。这是游戏的核心
/// 数据容器，管理玩家在游戏外的所有资产。
///
/// 初始化：
/// - 使用 Global::new() 创建新的全局状态（空仓库和空背包）
///
/// 使用场景：
/// - 访问玩家的铜偶仓库时
/// - 访问玩家的资源背包时
/// - 需要修改全局状态时
///
/// 注意事项：
/// - 全局状态在游戏启动时初始化
/// - 使用 Ref 类型，可以在函数间共享和修改
/// - 全局状态在游戏开始前和游戏结束后都会使用
/// - 可以通过加载存档更新全局状态
pub let global : Ref[Global] = Ref::new(Global::new())
