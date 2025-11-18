///|
/// 导入资源模块的类型（资源消耗和资源类型）
///
/// 该 using 语句导入 @resource 模块中的 ResourceCost 和 ResourceType 类型。
/// ResourceCost 用于表示资源消耗（如建造建筑、召唤单位所需的资源），
/// ResourceType 用于表示资源类型（如精炼铜、谐振星晶等）。这些类型在游戏
/// 逻辑中广泛使用，用于资源管理和消耗计算。
using @resource {type ResourceCost, type ResourceType}

///|
/// 导入铜偶模块的类型（铜偶类型）
///
/// 该 using 语句导入 @coppers 模块中的 Copper 类型。Copper 表示玩家的铜偶
/// 单位，包含铜偶的所有属性、等级、装备等信息。这个类型用于铜偶仓库管理和
/// 战斗铜偶创建。
using @coppers {type Copper}

///|
/// 导入随机数模块的函数（概率检查和随机数生成）
///
/// 该 using 语句导入 @rand 模块中的 check_probability 和 summon_random_number
/// 函数。check_probability 用于概率性事件判断（如材料生成概率），
/// summon_random_number 用于生成随机数（如随机选择敌人、随机位置等）。
/// 这些函数在游戏逻辑中用于随机性计算。
using @rand {check_probability, summon_random_number}

///|
/// 导入全局消息模块的消息系统（前端通信）
///
/// 该 using 语句导入 @global_msg 模块中的 msg_info 消息系统。msg_info 用于
/// 向后端和前端发送消息，实现前后端通信。这是游戏消息系统的核心，用于同步
/// 游戏状态和触发前端动画。
using @global_msg {msg_info}

///|
/// 导入全局状态模块的全局状态（玩家数据）
///
/// 该 using 语句导入 @global 模块中的 global 全局状态。global 存储玩家的
/// 铜偶仓库和资源背包，是游戏的核心数据容器。全局状态在游戏开始前和游戏
/// 结束后都会使用，管理玩家的所有资产。
using @global {global}

///|
/// 导入全局资源模块的物品类型（背包物品）
///
/// 该 using 语句导入 @global_resource 模块中的 Item 类型。Item 表示资源背包
/// 中的物品，可能包括资源、装备等。这个类型用于资源背包管理和物品处理。
using @global_resource {type Item}

///|
/// 导入ID模块的ID池（唯一标识符生成）
///
/// 该 using 语句导入 @id 模块中的 id_pool ID池。id_pool 用于生成全局唯一的
/// 标识符，分配给游戏中的各种单位（铜偶、敌人、建筑、材料等）。ID池确保每个
/// 单位都有唯一的标识符，用于前端识别和管理。
using @id {id_pool}

///|
/// 导入属性模块的属性类型（单位属性）
///
/// 该 using 语句导入 @attribute 模块中的 Attribute 类型。Attribute 表示单位
/// 的属性（生命值、速度、攻击力、防御力、闪避等），用于计算战斗属性和显示
/// 单位信息。这个类型在游戏逻辑中广泛使用，用于属性计算和战斗系统。
using @attribute {type Attribute}
