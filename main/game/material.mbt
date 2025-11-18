///|
/// 材料结构体（地图上可收集的资源物品）
///
/// 该结构体表示地图上可以收集的材料物品，如精炼铜锭、谐振星晶等。材料可以
/// 被玩家收集并转换为资源，用于建造建筑、召唤单位等。材料通常生成在房间的
/// 随机位置，玩家需要移动到材料位置才能收集。
///
/// 字段说明：
/// - id: 材料的唯一标识符，用于前端显示和管理
/// - material_base: 材料的基础信息（名称、资源类型、模型路径等）
priv struct Material {
  id : Int
  material_base : MaterialBase
} derive(ToJson)

///|
/// 材料基础信息结构体（材料的配置数据）
///
/// 该结构体定义了材料的基础属性，包括显示名称、对应的资源类型和3D模型路径。
/// 这些信息用于前端渲染和资源转换逻辑。
///
/// 字段说明：
/// - name: 材料的显示名称（如"精炼铜锭"、"谐振星晶"）
/// - resource_type: 材料对应的资源类型，收集后转换为该类型的资源
/// - model_url: 材料在3D场景中的模型文件路径（GLB格式）
priv struct MaterialBase {
  name : String
  resource_type : ResourceType
  model_url : String
} derive(ToJson)

///|
/// 创建新的材料实例
///
/// 该函数用于在地图上生成一个新的材料物品。函数会为材料分配一个唯一的ID，
/// 并设置材料的基础信息。生成的材料会被放置在地图的指定位置，玩家可以
/// 移动到该位置收集材料。
///
/// 参数说明：
/// - material_base: 材料的基础信息（名称、资源类型、模型路径等）
///
/// 返回值：
/// - 返回新创建的材料实例 Material
///
/// 执行流程：
/// 1. 从ID池获取一个唯一的ID（id_pool.get_id()）
/// 2. 使用传入的 material_base 创建材料实例
/// 3. 返回创建的材料实例
///
/// 使用场景：
/// - 在房间生成时随机放置材料
/// - 需要在地图上创建可收集的资源时
///
/// 注意事项：
/// - 材料生成后会占用地图位置，直到被玩家收集
/// - 材料收集后会转换为对应的资源类型
/// - 材料ID是全局唯一的，用于前端识别和管理
fn Material::new(material_base : MaterialBase) -> Material {
  { id: id_pool.get_id(), material_base }
}

///|
/// 精炼铜锭材料的基础配置
///
/// 该常量定义了精炼铜锭材料的所有基础属性。精炼铜锭是一种常见的材料，收集后
/// 会转换为精炼铜资源（RefinedCopper），可用于建造和召唤。
///
/// 属性说明：
/// - name: "精炼铜锭"（中文显示名称）
/// - resource_type: ResourceType::RefinedCopper（对应的资源类型）
/// - model_url: 精炼铜锭的3D模型路径
let refined_copper_ingot : MaterialBase = {
  name: "精炼铜锭",
  resource_type: ResourceType::RefinedCopper,
  model_url: "/assets/resource/refined_copper_ingot/refined_copper_ingot.glb",
}

///|
/// 谐振星晶材料的基础配置
///
/// 该常量定义了谐振星晶材料的所有基础属性。谐振星晶是一种稀有材料，收集后
/// 会转换为谐振星晶资源（ResonantCrystal），可用于高级建造和召唤。
///
/// 属性说明：
/// - name: "谐振星晶"（中文显示名称）
/// - resource_type: ResourceType::ResonantCrystal（对应的资源类型）
/// - model_url: 谐振星晶的3D模型路径
let resonant_star_crystal : MaterialBase = {
  name: "谐振星晶",
  resource_type: ResourceType::ResonantCrystal,
  model_url: "/assets/resource/resonant_star_crystal/resonant_star_crystal.glb",
}
