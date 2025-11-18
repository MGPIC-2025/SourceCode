///|
/// 建筑映射表（全局状态，存储所有建筑实例）
///
/// 该映射表存储游戏中所有建筑的实例，使用建筑ID作为键。建筑可以是玩家建造的
/// （如防御塔、矿钻、维修工坊），也可以是房间生成的（如充能线圈）。映射表用于
/// 快速查找和管理建筑。
let structure_map : Map[Int, Structure] = {}

///|
/// 建筑结构体（游戏中的建筑单位）
///
/// 该结构体表示游戏中的建筑单位，包括玩家建造的建筑和房间生成的建筑。建筑可以
/// 有攻击能力（如防御塔）、资源产出能力（如矿钻）、治疗能力（如维修工坊）等。
/// 建筑是游戏中的重要元素，提供防御、资源产出等功能。
///
/// 字段说明：
/// - id: 建筑的唯一标识符，用于前端识别和管理
/// - owned: 是否是玩家建造的建筑（true = 玩家建筑，false = 敌方建筑）
/// - position: 建筑在地图上的位置坐标 (x, y)
/// - can_attack: 本回合是否可以攻击（可变的，回合开始时重置）
/// - resource_type: 资源类型（可选），如果是心源矿钻，记录产出的资源类型
/// - now_health: 建筑当前血量（可变的，受到伤害时减少）
/// - structure_base: 建筑的基础信息（名称、属性、模型路径等）
priv struct Structure {
  id : Int
  owned : Bool // 是否是玩家建造的结构
  position : (Int, Int)
  mut can_attack : Bool // 是否可以攻击
  // 如果是心源矿钻，则需要记录资源类型
  resource_type : ResourceType?
  mut now_health : Float
  structure_base : StructureBase
} derive(ToJson)

///|
/// 建筑基础信息结构体（建筑的配置数据）
///
/// 该结构体定义了建筑的基础属性，包括显示名称、生命值、攻击能力、攻击范围、
/// 描述、资源消耗等。这些信息用于前端渲染和游戏逻辑计算。
///
/// 字段说明：
/// - name: 建筑的显示名称（如"防御塔"、"心源矿钻"、"维修工坊"）
/// - health: 建筑的最大生命值
/// - can_move: 建筑是否可以移动（通常为 false，建筑是固定的）
/// - can_attack: 建筑是否可以攻击（true = 有攻击能力，如防御塔）
/// - attack_range: 建筑的攻击范围（格子数，只有可攻击建筑才有意义）
/// - description: 建筑的描述文本，用于UI显示
/// - asset_url: 建筑的资源文件路径（可能未使用）
/// - model_url: 建筑在3D场景中的模型文件路径（GLB格式）
/// - attribute: 建筑的属性（攻击力、防御力等）
/// - cost: 建造建筑所需的资源消耗
struct StructureBase {
  name : String
  health : Float
  // 是否可以攻击，只有玩家建造出的可攻击结构可以攻击
  can_move : Bool
  can_attack : Bool
  attack_range : Int
  description : String
  asset_url : String
  model_url : String
  attribute : Attribute
  cost : ResourceCost
} derive(ToJson)

///|
/// 创建新的建筑实例
///
/// 该函数用于在地图上创建一个新的建筑实例。函数会为建筑分配一个唯一的ID，
/// 设置建筑的所有属性，并将建筑添加到全局建筑映射表中。建筑可以是玩家建造的
/// （如防御塔、矿钻），也可以是房间生成的（如充能线圈）。
///
/// 参数说明：
/// - structure_base: 建筑的基础信息（名称、属性、模型路径等）
/// - owned: 是否是玩家建造的建筑（true = 玩家建筑，false = 敌方建筑）
/// - resource_type: 资源类型（可选），如果是心源矿钻，传入产出的资源类型
/// - position: 建筑在地图上的位置坐标 (x, y)
///
/// 返回值：
/// - 返回新创建的建筑实例 Structure
///
/// 执行流程：
/// 1. 从ID池获取一个唯一的ID（id_pool.get_id()）
/// 2. 创建建筑实例，设置所有属性：
///    - id: 唯一标识符
///    - owned: 建筑归属
///    - position: 建筑位置
///    - can_attack: 初始化为 structure_base.can_attack
///    - now_health: 初始化为 structure_base.health（满血）
///    - resource_type: 传入的资源类型（矿钻需要）
///    - structure_base: 建筑基础信息
/// 3. 将建筑添加到全局建筑映射表（structure_map.set）
/// 4. 返回创建的建筑实例
///
/// 使用场景：
/// - 玩家建造建筑时
/// - 房间生成时放置建筑（如充能线圈）
/// - 需要创建建筑实例时
///
/// 注意事项：
/// - 建筑创建后立即添加到全局映射表
/// - 建筑初始血量为满血（structure_base.health）
/// - 矿钻建筑需要传入 resource_type，其他建筑为 None
/// - 建筑ID是全局唯一的，用于前端识别和管理
fn Structure::new(
  structure_base : StructureBase,
  owned~ : Bool,
  resource_type~ : ResourceType?,
  position : (Int, Int),
) -> Structure {
  let structure = {
    id: id_pool.get_id(),
    owned,
    position,
    can_attack: structure_base.can_attack,
    now_health: structure_base.health,
    resource_type,
    structure_base,
  }
  structure_map.set(structure.id, structure)
  structure
}

///|
/// 根据ID获取建筑实例（不安全操作）
///
/// 该函数用于根据建筑ID从全局建筑映射表中获取建筑实例。函数使用 unwrap()
/// 强制解包，如果ID不存在，会导致程序崩溃。因此这是一个不安全的操作。
///
/// 参数说明：
/// - id: 建筑的唯一标识符
///
/// 返回值：
/// - 返回建筑实例 Structure
/// - 如果ID不存在，会触发 panic
///
/// 使用场景：
/// - 需要根据ID访问建筑时（确保ID有效）
/// - 需要修改建筑状态时
///
/// 注意事项：
/// - 函数使用 unwrap()，如果ID无效会导致程序崩溃
/// - 确保在调用此函数前ID已经存在于映射表中
/// - 建议在调用前检查ID是否存在
fn get_structure_by_id(id : Int) -> Structure {
  structure_map.get(id).unwrap()
}

///|
/// 更新建筑的状态显示（更新前端UI）
///
/// 该函数用于更新建筑的状态显示，通知前端显示或隐藏建筑的可攻击状态指示器。
/// 函数会先清除建筑的所有状态，然后根据建筑是否有攻击能力显示红色圈圈。
/// 注意：建筑没有移动和召唤状态，只有攻击状态。
///
/// 参数说明：
/// - structure: 要更新状态的建筑实例
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 执行流程：
/// 1. 清除建筑的所有状态指示器（clear_state）
/// 2. 如果建筑有攻击能力（structure_base.can_attack = true）：
///    - 显示可攻击状态指示器（display_can_attack，红色圈圈）
///
/// 使用场景：
/// - 回合开始时更新建筑状态
/// - 建筑攻击后更新状态
/// - 需要显示建筑状态时
///
/// 注意事项：
/// - 建筑只有攻击状态，没有移动和召唤状态
/// - 只有有攻击能力的建筑才会显示红色圈圈
/// - 状态更新会立即反映到前端UI
fn Structure::update_move_and_attack_and_summon_status(
  structure : Structure,
) -> Unit {
  clear_state(structure.id)
  if structure.structure_base.can_attack {
    display_can_attack(structure.id, true)
  }
}

///|
/// 获取建筑的所有可攻击目标（计算攻击范围）
///
/// 该函数用于计算建筑的所有可攻击目标。函数会根据建筑的攻击范围，遍历范围内
/// 的所有位置，检查是否有可攻击的目标。目标的选择取决于建筑的归属：玩家建筑
/// 攻击敌方单位，敌方建筑攻击玩家单位。特殊地，维修工坊可以治疗玩家铜偶。
///
/// 参数说明：
/// - structure: 执行攻击的建筑实例
/// - map: 当前游戏地图实例，用于查询位置和占用者
///
/// 返回值：
/// - 返回 Array[CanAttackTarget] 类型，包含所有可攻击目标的数组
///
/// 执行流程：
/// 1. 获取建筑的攻击范围（structure_base.attack_range）
/// 2. 生成攻击范围内的所有偏移量（generate_offset）
/// 3. 遍历所有偏移量，计算目标位置：
///    a. 计算目标位置 = 建筑位置 + 偏移量
///    b. 检查目标位置是否被占用（map.is_occupy）
///    c. 如果被占用，获取占用者（map.get_occupant）
///    d. 根据建筑归属判断目标是否可攻击：
///       - 如果建筑是玩家拥有的（owned = true）:
///         * 维修工坊可以治疗玩家铜偶（Copper）
///         * 可以攻击野生敌人（Enemy，owned = false）
///         * 可以攻击敌方建筑（Structure，owned = false）
///       - 如果建筑是敌方的（owned = false）:
///         * 可以攻击玩家铜偶（Copper）
///         * 可以攻击友方召唤物（Enemy，owned = true）
///         * 可以攻击玩家建筑（Structure，owned = true）
///    e. 将可攻击目标添加到结果数组
/// 4. 返回所有可攻击目标的数组
///
/// 使用场景：
/// - 玩家点击建筑攻击按钮时显示攻击范围
/// - 需要计算建筑可攻击目标时
///
/// 注意事项：
/// - 攻击范围使用曼哈顿距离（generate_offset）
/// - 目标选择取决于建筑归属，玩家建筑和敌方建筑目标不同
/// - 维修工坊是特殊建筑，可以治疗玩家铜偶
/// - 只返回攻击范围内的目标，不考虑其他因素
fn Structure::get_attack_targets(
  structure : Structure,
  map : Map_,
) -> Array[CanAttackTarget] {
  let attack_range = structure.structure_base.attack_range
  let offset = generate_offset(attack_range)
  let can_attack = []
  for offset_ in offset {
    let position = (
      structure.position.0 + offset_.0,
      structure.position.1 + offset_.1,
    )
    if map.is_occupy(position) {
      let occupant = map.get_occupant(position)
      if structure.owned {
        match occupant {
          Copper(copper) if structure.structure_base.name == "维修工坊" =>
            can_attack.push(CanAttackTarget::Copper(copper))
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
/// 对建筑应用攻击伤害（计算伤害并判断是否被摧毁）
///
/// 该函数用于对建筑应用攻击伤害，计算建筑受到伤害后的血量，并判断建筑是否
/// 被摧毁。函数会直接减少建筑的血量，如果血量降至0或以下，返回 true 表示
/// 建筑被摧毁；否则返回 false。
///
/// 参数说明：
/// - structure: 受到攻击的建筑实例
/// - attack: 攻击伤害值（Float类型）
///
/// 返回值：
/// - 返回 Bool 类型
/// - true: 建筑被摧毁（血量 <= 0）
/// - false: 建筑未被摧毁（血量 > 0）
///
/// 执行流程：
/// 1. 减少建筑的血量：structure.now_health -= attack
/// 2. 判断建筑是否被摧毁：structure.now_health <= 0
/// 3. 返回判断结果
///
/// 使用场景：
/// - 建筑受到攻击时计算伤害
/// - 判断建筑是否被摧毁时
///
/// 注意事项：
/// - 伤害直接减少血量，不考虑防御力（建筑没有防御力）
/// - 如果血量降至0或以下，建筑被摧毁
/// - 建筑被摧毁后需要从地图和映射表中移除
/// - 确保在调用此函数后更新前端血量显示
fn Structure::apply_attack(structure : Structure, attack : Float) -> Bool {
  structure.now_health -= attack
  return structure.now_health <= 0
}
