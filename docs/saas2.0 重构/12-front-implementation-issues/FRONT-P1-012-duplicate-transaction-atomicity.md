# FRONT-P1-012 重复交易检查的实例边界

- 状态：CLOSED
- 优先级：P1
- 影响：需要明确当前实例检查和后续报表库跨实例检查的先后边界，避免遗漏四个实例之间的重复流水。

## 最新边界（2026-08-09 用户确认）

- 一个 `tenantId` 当前只归属一个实例，不要求增加跨实例分布式锁或改造当前业务库唯一约束。
- 重复交易边界只在当前银行、当前能力对应的物理业务表内判断。
- 防重键固定为 `tenantId + bizOrderNo + bizSubOrderNo`；同一组合不能重复。
- 不要求跨银行、跨能力、跨物理业务表全局唯一。
- 报表库是四个实例数据库的汇总，交易数据会进入报表库统一交易表；该表接入后，在当前业务表查询未命中时，
  保持当前银行/能力范围，再按 `tenantId + bizOrderNo + bizSubOrderNo` 查询一次报表库，补充跨实例唯一校验。
- 当前 report 查询接口和汇总表尚未接入，因此本轮只登记 TODO，不预造 Provider、Mapper、配置或调用挡板。

## 当前实现

- 两家 Transaction Handle 均使用 `ConcurrentHashMap + synchronized` 包住本 JVM 内的“查询 + 插入 INIT”窗口。
- 查询使用当前业务方法已确定的 Mapper，只检查当前物理业务表。
- 查询条件使用 `tenantId + bizOrderNo + bizSubOrderNo`，命中后返回 `TRANS_ALREADY_EXISTS`，不调用银行。
- 中信、平安两个公共 `checkDuplicateTransaction()` 已在本地查询之后登记 `TODO[REPORT]`；两个入口覆盖当前
  全部交易能力，report 接入时在此追加第二次查询。
- 不使用 requestHash、configVersion、快照或公共幂等节点。

## 验收标准

1. 当前银行、当前能力对应业务表内按 `tenantId + bizOrderNo + bizSubOrderNo` 精确检查。
2. 命中重复后不调用银行、不重放旧结果。
3. 系统故障不能被伪装成 `TRANS_ALREADY_EXISTS`。
4. 当前部署边界不增加跨实例分布式锁或改造业务库全局唯一方案。
5. report 尚未接入时保留明确 TODO；接入后执行“当前业务表查询 → report 当前银行/能力范围查询 → 插入 INIT”。
6. 不恢复 requestHash、configVersion、快照或公共幂等节点。

## 关闭记录（2026-08-09）

- 用户确认一个 `tenantId` 只归属一个实例，当前本地并发保护满足项目部署边界；
- 用户确认当前先保证业务表内三字段不重复，不需要跨实例锁；
- 用户补充确认报表库会汇总四个实例到统一交易表，待 report 接入后需要追加一次三字段查询，实现跨实例校验；
- 两家 Handle 已登记 TODO。本问题继续保持 CLOSED，report 能力建设后按 TODO 单独实施，不回退为当前缺陷。
