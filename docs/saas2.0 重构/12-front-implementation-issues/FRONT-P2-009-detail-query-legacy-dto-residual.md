# FRONT-P2-009 24/25 明细旧 DTO 在模块文档和常量注释中残留

- 状态：CLOSED
- 优先级：P2
- 核验时间：2026-08-19
- 影响：17 号 spec 已删除 `TransactionDetailItem/TransactionDetailQueryData`。模块 README 已在
  2026-08-19 修正；公共常量 Javadoc 已删除旧 DTO 名称，但字段名和 `DIGEST/REMARK` 去向仍写错，
  其他 AI 阅读常量类时仍会恢复错误映射。

## 当前证据

代码仓库执行：

```bash
rg -n "TransactionDetailItem|TransactionDetailQueryData" \
  catering-api catering-common catering-modules/catering-front
```

仍存在以下当前口径命中：

| 文件 | 未修复点 | 正确口径 |
|---|---|---|
| `CiticPlatformTransDetailQueryContractKeys.java` | `TRANS_TM` 写成不存在的 `transactionTime`；`DIGEST` 错写为主字段 `remark` | 映射 `PlatformTransDetailItem.transTime`；主字段 `remark` 取 `REMARK`，`DIGEST` 进入该行 `specialData` |
| `CiticTransDetailQueryContractKeys.java` | `TRANS_TM` 写成不存在的 `transactionTime`；`DIGEST` 错写为不存在的 `AccountTransDetailItem.remark` | 映射 `AccountTransDetailItem.transTime`；`DIGEST` 进入该行 `specialData` |

旧 Java 类文件已经删除，API/Controller/ApplicationService/BankQueryHandle 的实际泛型已正确；
本 Issue 只处理当前文档/Javadoc 残留，不修改运行逻辑。

## 修复要求

1. 模块 README 的两套分页泛型和行级 specialData 描述已修正，后续不得回退；
2. 修正两个中信明细 ContractKeys 类的 Javadoc，禁止重新创建旧 DTO；
3. 全仓 grep 只允许 17 号 spec、18 号 plan、Issue 修复历史中的“旧 → 新”迁移说明命中；
4. 同步 18 号 T11 静态执行报告，但在本 Issue 关闭和用户授权编译前不得勾选 T11；
5. 不新增测试类、不运行测试、不编译、不 commit、不 push，除非用户当次明确授权。

## 验收标准

1. `catering-api`、`catering-common`、`catering-modules/catering-front` 的当前 Java/Javadoc/README 中，
   `TransactionDetailItem|TransactionDetailQueryData` 为 0 命中；
2. 25/24 的模块 README 分别使用 `PlatformTransDetailItem` / `AccountTransDetailItem`；
3. 两套分页仍直接返回 `TableDataInfo<T>`，不包 `R`，不恢复 `FrontPageResult`；
4. 两个 ContractKeys 的响应字段注释与 17 号 §1.2 映射一致；
5. `git diff --check` 无空白错误。

## 关闭条件

修复后先改为 `FIXED_PENDING_REVIEW` 并记录实际文件和 grep 证据；只有用户确认后改为 `CLOSED`。

## 修复尝试记录（2026-08-19，未通过复核）

- 两个 ContractKeys 已将 `TransactionDetailItem` 名称分别替换为新 DTO，旧名称 grep 已清零；
- 但替换时未对照真实 DTO 字段和 Handle 映射，`transactionTime`、`DIGEST` 去向仍错误，验收标准第 4 项
  未满足，因此状态恢复为 `OPEN`。

## 关闭记录（2026-08-19，24/25 任务终验）

- `CiticPlatformTransDetailQueryContractKeys` 已明确 `TRANS_TM → PlatformTransDetailItem.transTime`；
- 25 的主字段 `remark` 已明确取 `REMARK`，`DIGEST` 进行级 `specialData`；
- `CiticTransDetailQueryContractKeys` 已明确 `TRANS_TM → AccountTransDetailItem.transTime`，
  `DIGEST` 进行级 `specialData`；
- 代码仓 `catering-api/catering-common/catering-modules/catering-front` 当前 Java/README 中
  `TransactionDetailItem|TransactionDetailQueryData|FrontPageResult` 当前口径 0 命中；
- 两个明细接口仍直接返回 `TableDataInfo<T>`，`git diff --check` 无空白错误。

本 Issue 的注释和旧 DTO 残留已验收通过；其他文档漂移由
`FRONT-P2-008` 跟踪，分页失败 `totalPage` 缺口由 `FRONT-P1-015` 跟踪。
