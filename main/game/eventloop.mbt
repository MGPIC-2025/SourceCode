///|
/// 游戏事件主循环处理函数（前端消息入口点）
///
/// 该函数是游戏事件系统的核心入口，负责接收前端发送的JSON格式消息，解析消息类型
/// 和内容，然后分发到对应的处理函数。函数支持多种游戏事件类型，包括：铜偶操作、
/// 敌人操作、建筑操作、游戏流程控制等。所有消息都通过JSON字符串传递，数字类型
/// 也需要转换为字符串发送，以避免后端 as_number 再 to_int 可能存在的精度问题。
///
/// 参数说明：
/// - msg: 前端发送的JSON格式消息字符串，包含 type 和 content 字段
///
/// 返回值：
/// - 返回 Unit 类型（无返回值）
///
/// 消息格式：
/// 所有消息都遵循以下JSON格式：
/// {
///   "type": "消息类型字符串",
///   "content": { ... 消息内容对象 ... }
/// }
///
/// 支持的消息类型：
/// - on_click_copper: 点击铜偶事件
/// - on_attack_start: 开始攻击事件
/// - on_attack_end: 结束攻击事件
/// - on_attack_apply: 应用攻击事件
/// - on_move_start: 开始移动事件
/// - on_move_end: 结束移动事件
/// - on_move_apply: 应用移动事件
/// - on_game_start: 游戏开始事件
/// - on_game_round_pass: 游戏回合结束事件
/// - on_click_enemy: 点击敌人事件
/// - on_enemy_attack_start: 敌人开始攻击事件
/// - on_enemy_attack_end: 敌人结束攻击事件
/// - on_enemy_attack_apply: 敌人应用攻击事件
/// - on_enemy_move_start: 敌人开始移动事件
/// - on_enemy_move_end: 敌人结束移动事件
/// - on_enemy_move_apply: 敌人应用移动事件
/// - on_get_summon_menu: 获取召唤菜单事件
/// - on_summon_start: 开始召唤事件
/// - on_summon_apply: 应用召唤事件
/// - on_summon_end: 结束召唤事件
/// - on_click_structure: 点击建筑事件
/// - on_get_structure_menu: 获取建筑菜单事件
/// - on_structure_build_start: 开始建造建筑事件
/// - on_structure_build_apply: 应用建造建筑事件
/// - on_structure_build_end: 结束建造建筑事件
/// - on_structure_attack_start: 建筑开始攻击事件
/// - on_structure_attack_end: 建筑结束攻击事件
/// - on_structure_attack_apply: 建筑应用攻击事件
/// - on_game_over: 游戏结束事件
///
/// 使用场景：
/// - 前端发送任何游戏操作时
/// - 需要处理用户交互时
/// - 游戏状态同步时
///
/// 注意事项：
/// - 所有数字类型都需要转换为字符串发送，避免精度问题
/// - 消息解析失败会触发程序终止（使用 try! 和 unwrap()）
/// - 无效的消息类型会触发 abort("Invalid message")
/// - 函数是异步的，不会阻塞游戏主循环
pub fn eventloop(msg : String) -> Unit {
  let msg = try! @json.parse(msg)
  match msg {
    { "type": "on_click_copper", "content": { "id": id, .. }, .. } =>
      handle_on_click_copper(string_to_int(id))
    { "type": "on_attack_start", "content": { "id": id, .. }, .. } =>
      handle_on_attack_start(force_get_current_map(), string_to_int(id))
    { "type": "on_attack_end", .. } => handle_on_attack_end()
    {
      "type": "on_attack_apply",
      "content": { "id": id, "position": { "x": x, "y": y, .. }, .. },
      ..
    } =>
      handle_on_attack_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
      )
    { "type": "on_move_start", "content": { "id": id, .. }, .. } =>
      handle_on_move_start(force_get_current_map(), string_to_int(id))
    { "type": "on_move_end", .. } => handle_on_move_end()
    {
      "type": "on_move_apply",
      "content": { "id": id, "position": { "x": x, "y": y, .. }, .. },
      ..
    } =>
      handle_on_move_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
      )
    { "type": "on_game_start", "content": { "ids": ids, .. }, .. } =>
      handle_on_game_start(ids.as_array().unwrap().map(string_to_int))
    { "type": "on_game_round_pass", .. } => handle_game_round_pass()
    { "type": "on_click_enemy", "content": { "id": id, .. }, .. } =>
      handle_on_click_enemy(string_to_int(id))
    { "type": "on_enemy_attack_start", "content": { "id": id, .. }, .. } =>
      handle_on_enemy_attack_start(force_get_current_map(), string_to_int(id))
    { "type": "on_enemy_attack_end", .. } => handle_on_enemy_attack_end()
    {
      "type": "on_enemy_attack_apply",
      "content": { "id": id, "position": { "x": x, "y": y, .. }, .. },
      ..
    } =>
      handle_on_enemy_attack_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
      )
    { "type": "on_enemy_move_start", "content": { "id": id, .. }, .. } =>
      handle_on_enemy_move_start(force_get_current_map(), string_to_int(id))
    { "type": "on_enemy_move_end", .. } => handle_on_enemy_move_end()
    {
      "type": "on_enemy_move_apply",
      "content": { "id": id, "position": { "x": x, "y": y, .. }, .. },
      ..
    } =>
      handle_on_enemy_move_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
      )
    { "type": "on_get_summon_menu", .. } => handle_on_get_summon_menu()
    { "type": "on_summon_start", "content": { "id": id, .. }, .. } =>
      handle_on_summon_start(string_to_int(id))
    {
      "type": "on_summon_apply",
      "content": {
        "id": id,
        "position": { "x": x, "y": y, .. },
        "name": name,
        ..
      },
      ..
    } =>
      handle_on_summon_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
        name.as_string().unwrap(),
      )
    { "type": "on_summon_end", .. } => handle_on_summon_end()
    { "type": "on_click_structure", "content": { "id": id, .. }, .. } =>
      handle_on_click_structure(string_to_int(id))
    { "type": "on_get_structure_menu", .. } => handle_on_get_structure_menu()
    {
      "type": "on_structure_build_start",
      "content": { "id": id, "name": name, .. },
      ..
    } =>
      handle_on_structure_build_start(
        string_to_int(id),
        name.as_string().unwrap(),
      )
    {
      "type": "on_structure_build_apply",
      "content": {
        "id": id,
        "position": { "x": x, "y": y, .. },
        "name": name,
        ..
      },
      ..
    } =>
      handle_on_structure_build_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
        name.as_string().unwrap(),
      )
    { "type": "on_structure_build_end", .. } => handle_on_structure_build_end()
    { "type": "on_structure_attack_start", "content": { "id": id, .. }, .. } =>
      handle_on_structure_attack_start(
        force_get_current_map(),
        string_to_int(id),
      )
    { "type": "on_structure_attack_end", .. } =>
      handle_on_structure_attack_end()
    {
      "type": "on_structure_attack_apply",
      "content": { "id": id, "position": { "x": x, "y": y, .. }, .. },
      ..
    } =>
      handle_on_structure_attack_apply(
        string_to_int(id),
        (string_to_int(x), string_to_int(y)),
        force_get_current_map(),
      )
    { "type": "on_game_over", .. } => handle_on_game_over()
    _ => abort("Invalid message")
  }
}

///|
/// 将JSON字符串转换为整数（辅助函数）
///
/// 该函数是一个辅助函数，用于从JSON对象中提取字符串并转换为整数。主要用于
/// eventloop 函数中解析前端传来的数字参数。由于精度问题，前端会将数字作为
/// 字符串发送，后端需要先提取字符串再转换为整数。
///
/// 参数说明：
/// - json: JSON对象，应该包含一个可以转换为整数的字符串值
///
/// 返回值：
/// - 返回 Int 类型，表示转换后的整数值
/// - 如果JSON不是字符串或字符串无法转换为整数，会触发程序终止
///
/// 转换流程：
/// 1. 使用 json.as_string().unwrap() 将JSON提取为字符串
/// 2. 使用 @strconv.parse_int() 将字符串解析为整数
/// 3. 使用 try! 处理可能的解析错误（失败会终止程序）
///
/// 使用场景：
/// - eventloop 函数中解析消息参数时
/// - 需要从JSON中提取整数ID时
/// - 需要将字符串坐标转换为整数坐标时
///
/// 注意事项：
/// - 函数使用 unwrap() 和 try!，解析失败会导致程序崩溃
/// - 确保传入的JSON包含有效的整数字符串
/// - 主要用于处理前端传来的ID和坐标参数
fn string_to_int(json : Json) -> Int {
  try! @strconv.parse_int(json.as_string().unwrap())
}
