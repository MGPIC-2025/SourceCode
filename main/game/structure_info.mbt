///|
/// 建筑信息列表（所有可建造建筑的配置数据）
///
/// 该数组包含游戏中所有可建造建筑的基础信息配置。每个建筑配置包括名称、生命值、
/// 攻击能力、攻击范围、描述、模型路径、资源消耗等完整数据。这些数据用于前端
/// 显示建筑菜单和游戏逻辑计算建筑属性。注意：某些建筑（如充能线圈）可能不会
/// 显示在建造菜单中，但配置仍然存在。
///
/// 建筑列表：
/// 1. 铆接壁垒 - 防御建筑，400生命值，不可攻击，消耗8精炼铜+2召回齿轮
/// 2. 齿轮箭塔 - 攻击建筑，180生命值，攻击范围3，攻击力30，消耗6精炼铜+3召回齿轮
/// 3. 心源矿钻 - 资源建筑，300生命值，不可攻击，消耗10精炼铜+4召回齿轮+5心晶粉尘
/// 4. 充能线圈 - 特殊建筑，200生命值，不可攻击，消耗20精炼铜+6召回齿轮+10谐振星晶
/// 5. 维修工坊 - 治疗建筑，200生命值，攻击范围3，攻击力25（用于治疗），消耗8精炼铜+3召回齿轮+3心晶粉尘
/// 6. 镜光折射塔 - 高级攻击建筑，1200生命值，攻击范围5，攻击力120，消耗30精炼铜+20谐振星晶+10心晶粉尘+8灵源火花
/// 7. 共鸣警钟 - 攻击建筑，500生命值，攻击范围4，攻击力60，消耗15精炼铜+5召回齿轮+8谐振星晶
/// 8. 风暴铁砧 - 高级攻击建筑，800生命值，攻击范围4，攻击力100，消耗25精炼铜+15谐振星晶+5灵源火花
///
/// 注意事项：
/// - 数组是固定大小的（FixedArray），不能动态修改
/// - 每个建筑配置包含完整的属性数据
/// - 某些建筑可能在前端被过滤，不会显示在建造菜单中
/// - 建筑配置用于创建建筑实例和显示建筑信息
let structure_info_list : FixedArray[StructureBase] = [
  {
    name: "铆接壁垒",
    health: 400,
    can_move: false,
    can_attack: false,
    attack_range: 0,
    description: " 一段坚固的、由巨大黄铜板铆接而成的城墙，板上有蒸汽管道加固。墙头有齿轮驱动的可动挡板，墙体内嵌有发出稳定黄光的观察灯。",
    asset_url: "assets/structure/riveted_barrier/riveted_barrier.webp",
    model_url: "assets/structure/riveted_barrier/riveted_barrier.glb",
    attribute: Attribute::new(health=0, speed=0, attack=0, defense=0, dodge=0),
    cost: ResourceCost::new([(RefinedCopper, 8), (RecallGear, 2)]),
  },
  {
    name: "齿轮箭塔",
    health: 180,
    can_move: false,
    can_attack: true,
    attack_range: 3,
    description: "一座细高的塔楼，顶部是一个开放式齿轮组平台，通过传送带将铜质弩箭自动上弦并连续发射。塔身有蒸汽泄压阀，每次齐射都伴随“嘶嘶”声。",
    asset_url: "assets/structure/gear_arrow_tower/gear_arrow_tower.webp",
    model_url: "assets/structure/gear_arrow_tower/gear_arrow_tower.glb",
    attribute: Attribute::new(health=0, speed=0, attack=30, defense=0, dodge=0),
    cost: @resource.ResourceCost::new([(RefinedCopper, 6), (RecallGear, 3)]),
  },
  {
    name: "心源矿钻",
    health: 300,
    can_move: false,
    can_attack: false,
    attack_range: 0,
    description: "一台顶部装有巨大钻头的大型钻井装置，由复杂的齿轮组和活塞驱动。钻头高速旋转，闪烁着蓝光，从地底带出发光的矿石。",
    asset_url: "assets/structure/heart_source_drill/heart_source_mineral_drill.webp",
    model_url: "assets/structure/heart_source_drill/heart_source_mineral_drill.glb",
    attribute: Attribute::new(health=0, speed=0, attack=0, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 10),
      (RecallGear, 4),
      (HeartCrystalDust, 5),
    ]),
  },
  {
    name: "充能线圈",
    health: 200,
    can_move: false,
    can_attack: false,
    attack_range: 0,
    description: "一个由巨大铜线圈缠绕而成的塔状建筑，线圈中央有电弧在不断跳跃。它能够为周围一定范围内的友方建筑提供能量，使其运作更快。",
    asset_url: "assets/structure/charging_coil/charging_coil.webp",
    model_url: "assets/structure/charging_coil/charging_coil.glb",
    attribute: Attribute::new(health=0, speed=0, attack=0, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 20),
      (RecallGear, 6),
      (ResonantCrystal, 10),
    ]),
  },
  {
    name: "维修工坊",
    health: 200,
    can_move: false,
    can_attack: true,
    attack_range: 3,
    description: "一个带有可开合顶棚的圆形工坊，内部有多个机械臂。友方铜偶经过时，机械臂会自动为其进行修复和保养，发出叮叮当当的敲打声。",
    asset_url: "assets/structure/repair_workshop/repair_workshop.webp",
    model_url: "assets/structure/repair_workshop/repair_workshop.glb",
    attribute: Attribute::new(health=0, speed=0, attack=25, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 8),
      (RecallGear, 3),
      (HeartCrystalDust, 3),
    ]),
  },
  {
    name: "镜光折射塔",
    health: 1200,
    can_move: false,
    can_attack: true,
    attack_range: 5,
    description: "一座顶部镶嵌着巨大、可转动水晶镜片的塔。它能聚集环境中的心源能量，发射出一道灼热的折射光束，对直线上的敌人造成伤害。",
    asset_url: "assets/structure/mirror_refractory_tower/mirror_light_refraction_tower.webp",
    model_url: "assets/structure/mirror_refractory_tower/mirror_light_refraction_tower.glb",
    attribute: Attribute::new(health=0, speed=0, attack=120, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 30),
      (ResonantCrystal, 20),
      (HeartCrystalDust, 10),
      (SpiritalSpark, 8),
    ]),
  },
  {
    name: "共鸣警钟",
    health: 500,
    can_move: false,
    can_attack: true,
    attack_range: 4,
    description: "一个悬挂在精致黄铜钟楼里的大钟，钟体刻有共鸣符文。当敌人靠近时，它会自动鸣响，发出可见的声波涟漪。",
    asset_url: "assets/structure/resonance_alarm_bell/resonance_alarm_bell.webp",
    model_url: "assets/structure/resonance_alarm_bell/resonance_alarm_bell.glb",
    attribute: Attribute::new(health=0, speed=0, attack=60, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 15),
      (RecallGear, 5),
      (ResonantCrystal, 8),
    ]),
  },
  {
    name: "风暴铁砧",
    health: 800,
    can_move: false,
    can_attack: true,
    attack_range: 4,
    description: "一个被闪电线圈环绕的巨大铁砧。它会定期引动空气中的能量，召唤一道小范围的闪电风暴，轰击区域内的所有敌人。",
    asset_url: "assets/structure/storm_iron_anvil/storm_anvil.webp",
    model_url: "assets/structure/storm_iron_anvil/storm_anvil.glb",
    attribute: Attribute::new(health=0, speed=0, attack=100, defense=0, dodge=0),
    cost: ResourceCost::new([
      (RefinedCopper, 25),
      (ResonantCrystal, 15),
      (SpiritalSpark, 5),
    ]),
  },
]

///|
/// 建筑信息映射表（建筑名称到配置的快速查找）
///
/// 该映射表将建筑名称映射到对应的建筑配置数据，用于根据建筑名称快速查找建筑
/// 信息。映射表从 structure_info_list 数组构建，使用建筑名称作为键。这用于
/// 在游戏逻辑中根据建筑名称获取建筑配置，如建造建筑时根据名称查找配置。
///
/// 构建方式：
/// - 从 structure_info_list 数组迭代
/// - 将每个建筑配置映射为 (建筑名称, 建筑配置) 的键值对
/// - 使用 Map::from_iter 构建映射表
///
/// 使用场景：
/// - 根据建筑名称查找建筑配置时
/// - 建造建筑时获取建筑属性时
/// - 需要快速查找建筑信息时
///
/// 注意事项：
/// - 键是建筑名称（String），值是建筑配置（StructureBase）
/// - 映射表在程序启动时构建，不会动态更新
/// - 如果建筑名称不存在，查找会返回 None
/// - 用于游戏逻辑中的建筑配置查找
pub let structure_info_map : Map[String, StructureBase] = Map::from_iter(
  structure_info_list
  .iter()
  .map(structure_info => (structure_info.name, structure_info)),
)
