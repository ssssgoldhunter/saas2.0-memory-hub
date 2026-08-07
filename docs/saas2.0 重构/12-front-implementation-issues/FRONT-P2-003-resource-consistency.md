# FRONT-P2-003 LiteFlow 与 DDL 存在多份冲突资源

- 状态：OPEN
- 优先级：P2
- 影响：不同环境或后续 AI 可能选择错误规则文件或错误建表脚本。

## 证据

- 同时存在：
  - `catering-front/src/main/resources/front-flow.xml`
  - `catering-front/src/main/resources/liteflow/front-flow.xml`
- Nacos 当前 `rule-source` 指向根目录 `front-flow.xml`。
- 代码仓库 `db/migration/V001__create_front_bank_business_transaction_tables.sql` 仍包含已禁止的
  `interface_code/config_version/request_hash/MEDIUMTEXT 快照/front_resp_code/send_started_at` 等字段。
- 记忆体最终权威脚本是 `09-final-rebuild-all-tables.sql`。

## 验收标准

1. LiteFlow 仅保留一份权威规则，Nacos、README、WIKI 路径一致。
2. 删除或明确废弃旧 V001，代码仓库不再携带与最终 DDL 冲突的可执行脚本。
3. 最终 DDL 固定为 10 张银行 + 业务表，每表三个 reserve 字段，无整段快照。
4. 未明确部署迁移方案前，不擅自引入 Flyway 或自动执行 DROP/CREATE。
