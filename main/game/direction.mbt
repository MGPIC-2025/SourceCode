///|
priv enum Direction {
  Left
  Right
  Up
  Down
  LeftUp
  LeftDown
  RightUp
  RightDown
}

///|
/// 将内部方向枚举转换为单位方向枚举（用于系统内部使用）
///
/// 该函数用于将游戏内部使用的 Direction 枚举（包含8个方向：上下左右和对角线）
/// 转换为系统内部使用的 UnitDirection 枚举（只包含4个基本方向：正负X、正负Y）。
/// 注意：对角线方向无法转换为单位方向，会触发程序终止。
///
/// 参数说明：
/// - direction: 需要转换的 Direction 枚举值
///
/// 返回值：
/// - 返回对应的 UnitDirection 枚举值
/// - 如果传入对角线方向会触发 abort（程序终止）
///
/// 转换映射规则：
/// - Left（左） → NegativeX（负X方向）
/// - Right（右） → PositiveX（正X方向）
/// - Up（上） → PositiveY（正Y方向）
/// - Down（下） → NegativeY（负Y方向）
/// - LeftUp、LeftDown、RightUp、RightDown（对角线方向） → 触发 abort
///
/// 使用场景：
/// - 需要将方向转换为系统内部单位方向时
/// - 方向计算和坐标变换时
/// - 需要限制为基本方向时
///
/// 注意事项：
/// - 对角线方向无法转换，传入会触发程序崩溃
/// - 确保只传入基本方向（上下左右）
/// - 该函数主要用于系统内部，不直接用于游戏逻辑
fn convert_direction_to_unit_direction(direction : Direction) -> UnitDirection {
  match direction {
    Left => NegativeX
    Right => PositiveX
    Up => PositiveY
    Down => NegativeY
    LeftUp | LeftDown | RightUp | RightDown => abort("Invalid direction")
  }
}

///|
/// 根据单位的当前位置和目标位置，计算移动后单位应该朝向的方向
///
/// 该函数用于计算单位从当前位置移动到目标位置后应该面向的方向。函数会计算
/// 两个位置之间的相对偏移，然后根据偏移量确定方向。方向映射规则基于前端3D
/// 场景的期望：前端使用Z轴作为默认朝向，需要将2D地图坐标转换为3D场景中的
/// 旋转角度。
///
/// 参数说明：
/// - position_from: 单位的当前位置坐标 (x, y)
/// - position_to: 单位的目标位置坐标 (x, y)
///
/// 返回值：
/// - 返回 Direction 枚举值，表示移动后应该朝向的方向
///
/// 方向计算逻辑：
/// 1. 计算相对偏移：relative_x = position_to.0 - position_from.0
///                  relative_y = position_to.1 - position_from.1
/// 2. 优先判断X轴方向（如果 relative_x != 0）：
///    - relative_x > 0（向右移动） → 返回 Up（前端保持0度朝向+Z）
///    - relative_x < 0（向左移动） → 返回 Down（前端转到180度朝向-Z）
/// 3. 如果X轴为0，判断Y轴方向：
///    - relative_y > 0（向上移动） → 返回 Left（前端转到-90度）
///    - relative_y < 0（向下移动） → 返回 Right（前端转到90度）
///
/// 前端映射规则（基于3D场景）：
/// - X+ (向右) → 保持朝向+Z(0度) → 发送Up
/// - Y+ (向上) → 转到90度 → 发送Right
/// - Y- (向下) → 转到-90度 → 发送Left
/// - X- (向左) → 转到180度 → 发送Down
///
/// 使用场景：
/// - 单位移动后更新朝向时
/// - 需要计算单位应该面向的方向时
/// - 同步单位方向到前端显示时
///
/// 注意事项：
/// - 函数只处理基本方向（上下左右），不处理对角线移动
/// - 如果两个位置相同，会返回最后一个判断的方向（Right）
/// - 方向映射基于前端3D场景的坐标系统
/// - X轴优先于Y轴判断，确保方向一致性
fn get_direction_by_position(
  position_from : (Int, Int),
  position_to : (Int, Int),
) -> Direction {
  let relative_x = position_to.0 - position_from.0
  let relative_y = position_to.1 - position_from.1
  if relative_x != 0 {
    if relative_x > 0 {
      // X+ (向右) → 发送Up (前端保持0度朝向+Z)
      Up
    } else {
      // X- (向左) → 发送Down (前端转到180度朝向-Z)
      Down
    }
  } else if relative_y > 0 {
    // Y+ (向上) → 发送Left (前端转到-90度)
    Left
  } else {
    // Y- (向下) → 发送Right (前端转到90度)
    Right
  }
}
