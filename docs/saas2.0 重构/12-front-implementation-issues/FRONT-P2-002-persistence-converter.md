# FRONT-P2-002 Handle 反射赋值违反对象转换约束

- 状态：OPEN
- 优先级：P2
- 影响：字段缺失可能被静默忽略，编译期无法发现 Entity 结构变化。

## 证据

- 中信、平安 Transaction Handle 使用 `invokeSetter/findSetter` 反射填充 Entity。
- `interfaceCode/configVersion` 被传入公共填充方法但没有实际保存，属于无效参数。
- 05 号约束要求 Entity/VO 转换使用 `@AutoMapper + MapstructUtils.convert`。

## 验收标准

1. 删除 Handle 中的反射 setter。
2. 建立明确的业务数据到各交易 Entity 的转换/装配方式。
3. 公共字段和银行业务字段均可在编译期发现遗漏。
4. 不恢复 DDL 已删除的 interfaceCode/configVersion 字段。
5. Entity、VO、Mapper XML、最终 DDL 字段逐项对齐。
