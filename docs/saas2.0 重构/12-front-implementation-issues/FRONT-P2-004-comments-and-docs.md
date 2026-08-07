# FRONT-P2-004 Java 注释和历史文档存在过时口径

- 状态：OPEN
- 优先级：P2
- 影响：其他 AI 可能根据注释重新实现已废弃的快照、幂等或错误路由逻辑。

## 已确认示例

- `FrontBaseRequestData` 注释称 `zxegj/pajzb` 使用 `BankCode.valueOf` 转换。
- `BaseTransactionBusinessData` 注释称保存完整 baseData 加密快照，并称 bizRequestNo 是幂等键。
- `BaseRequest.dataSourceId` 注释称用于分库路由；当前约束为只记录，实际分片键是 tenant_id。
- `FrontIdempotencyCheckNode` 仍描述 requestHash 和旧结果重放。
- 00/02/03 中保留 platformCode 待确认、旧 functionFlag 或旧 baseData 边界等历史描述。
- WIKI 中历史“编译通过”不能代表当前未提交工作树状态。

## 验收标准

1. Java 对象和 Slot 字段注释说明真实用途、来源和禁止边界。
2. 删除快照、旧幂等、错误 valueOf、dataSourceId 路由等过时描述。
3. 旧能力文档保留历史内容时显式标注 superseded，并指向当前契约。
4. WIKI 的“已实现/未实现”与当前代码审查结果一致，不把历史编译记录当成当前验收结果。
