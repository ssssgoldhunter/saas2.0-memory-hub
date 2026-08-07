# FRONT-P1-003 分页 code/msg/total 和游标协议不符合约束

- 状态：OPEN
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
