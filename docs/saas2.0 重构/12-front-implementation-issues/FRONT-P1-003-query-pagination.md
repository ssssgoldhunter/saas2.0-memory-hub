# FRONT-P1-003 分页 code/msg/total 和游标协议不符合约束

- 状态：CLOSED
- 优先级：P1
- 影响：分页成功可能返回 `code=0/msg=null/total=0`，调用方无法正确翻页。

## 证据

- `FrontQueryApplicationService` 成功分支使用无参 `new TableDataInfo<>()`，未设置成功 code/msg。
- `CiticQueryHandle` 读取 `TOTAL_PAGE` 并生成 continuationToken，没有读取已定义的 `totalNum`。
- `TransactionDetailQueryData`、`FrontPageResult` 仍包含 `continuationToken`。

## 修改范围

- `FrontQueryApplicationService`
- `CiticQueryHandle`
- `TransactionDetailQueryData`
- `FrontPageResult`
- 中信查询常量和 10 号字段契约实现状态。

## 验收标准

1. 成功固定 `code=200/msg=查询成功`。
2. `totalNum` 映射为 `TableDataInfo.total`，不得用总页数代替。
3. 对外仅使用 `pageNo/pageSize + total`。
4. 删除请求、返回和 Handle 中的 continuationToken 逻辑。
5. 中信 24 固定每页 50，25 固定每页 20。

## 当前修复证据（2026-08-09 静态审查）

- 单笔查询返回 `R<T>`，两个分页接口返回 `TableDataInfo<TransactionDetailItem>`。
- 成功分页设置 `code=200/msg=查询成功`，银行 `totalNum` 映射到 `total`。
- continuationToken 已从当前 API 和 Handle 逻辑删除，中信 24/25 页大小分别固定为 50/20。
- 分页失败 rows 为空列表的缺口继续由 `FRONT-P0-003` 跟踪，不在本问题重复登记。
- 用户已确认关闭；本轮未重新执行编译或测试。
