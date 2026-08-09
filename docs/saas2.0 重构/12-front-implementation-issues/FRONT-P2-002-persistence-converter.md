# FRONT-P2-002 Handle 反射赋值违反对象转换约束

- 状态：CLOSED
- 优先级：P2
- 影响：字段缺失可能被静默忽略，编译期无法发现 Entity 结构变化。

## 证据

- 中信、平安 Transaction Handle 使用 `invokeSetter/findSetter` 反射填充 Entity。
- `interfaceCode` 被传入公共填充方法但没有实际保存，属于无效参数。
- 05 号约束要求 Entity/VO 转换使用 `@AutoMapper + MapstructUtils.convert`。

## 验收标准

1. 删除 Handle 中的反射 setter。
2. 建立明确的业务数据到各交易 Entity 的转换/装配方式。
3. 公共字段和银行业务字段均可在编译期发现遗漏。
4. 不恢复 DDL 已删除的 interfaceCode 等冗余字段。
5. 本问题涉及的 Entity、VO 和持久化装配字段逐项对齐；平台收付款的独立方向错位统一由 `FRONT-P1-009` 跟踪。

## 当前修复证据（2026-08-09 静态审查）

- 当前 Transaction Handle 已无 `invokeSetter/findSetter` 或反射 setter。
- Handle 使用明确 setter 装配不同交易 Entity，Entity/VO 服务转换继续使用 `MapstructUtils.convert`。
- 平台收付款 Mapper/DDL 方向错位不再重复挂在本问题，统一保留在 `FRONT-P1-009`。
- 用户已确认关闭；本轮未重新执行编译或测试。
