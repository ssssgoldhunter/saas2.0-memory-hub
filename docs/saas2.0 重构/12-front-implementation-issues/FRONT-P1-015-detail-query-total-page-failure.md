# FRONT-P1-015 24/25 明细失败返回缺少 totalPage

- 状态：CLOSED（2026-08-20 用户确认关闭）
- 优先级：P1
- 核验时间：2026-08-20
- 修复结果：中信非法 `TOTAL_PAGE` 已统一转为 `WALLET_RESPONSE_INVALID`；web-test 的
  Feign 异常兜底已固定返回 `total=0,totalPage=0,rows=[]`。

## 任务边界

1. 本问题只属于“24/25 明细查询对外契约重构 + 平安明细启用”。
2. 不修改平安退款、账户状态/余额挡板、report 查重或交易持久化。
3. 不恢复 `FrontPageResult`，不在 `TableDataInfo` 外包 `R`。

## 首次核验证据

17 号 spec §1.2 规定明细失败时 `code/msg/total/totalPage/rows` 需一并填好；
10 号契约 §7 的失败示例明确为：

```json
{
  "code": 500,
  "msg": "银行拒绝交易",
  "rows": [],
  "total": 0,
  "totalPage": 0
}
```

首次核验时 `TableDataInfo.totalPage` 是未初始化的 `Long`，以下分支新建结果后只设置
`code/msg`，因此序列化为 `totalPage:null`：

1. `CiticQueryHandle.queryPlatformDetails()` 银行失败分支；
2. `CiticQueryHandle.queryAccountDetails()` 银行失败分支；
3. `PingAnQueryHandle.parseClearWithdrawDetail()` 失败分支；
4. `PingAnQueryHandle.parseTransferRechargeDetail()` 失败分支；
5. `PingAnQueryHandle.parseWithdrawReturnTicket()` 失败分支；
6. `FrontQueryApplicationService.resolvePageResult()` 业务中断分支；
7. `BankQueryHandle.unsupportedTableData()` 默认失败分支。

此外，首次核验时中信成功应答如缺少 `TOTAL_PAGE`，会返回成功码但
`totalPage=null`，同样不满足固定契约。

## 建议修复思路

1. 优先做局部修复：所有24/25明细失败构造分支统一设置
   `total=0`、`totalPage=0L`、`rows=[]`；避免无评审地改变全项目其他 `TableDataInfo` 接口。
2. 中信成功应答中 `TOTAL_PAGE` 缺失或无法解析时，不得返回
   `code=200,totalPage=null`；应按银行应答格式错误收口为失败分页结果。
3. web-test 的 Feign 失败兜底如需保证对外显示一致，同步设置
   `totalPage=0L`。

## 验收标准

1. 24/25 明细的成功、银行业务失败、LiteFlow 业务中断和默认不支持分支，
   都返回非 `null` 的 `totalPage`。
2. 失败结果固定 `code=500,total=0,totalPage=0,rows=[]`，`msg` 为安全可读文案。
3. 中信成功应答缺少/非法 `TOTAL_PAGE` 时不伪装为成功。
4. 两个明细接口仍直接返回 `TableDataInfo<新行DTO>`，状态查询仍返回
   `R<TransStatusResult>`。
5. 不新增测试类；是否编译以用户当次授权为准。

## 第二轮静态复核（2026-08-19，问题修复后）

原问题列出的 7 个服务端失败构造分支均已补齐
`total=0`、`totalPage=0`；`TableDataInfo.rows` 由默认空列表保证非 `null`。
中信应答缺少或为空的 `TOTAL_PAGE` 也已转为 `WALLET_RESPONSE_INVALID`。

但本 Issue 仍不能关闭，当前剩余 2 个可复现点：

| 文件 | 未修复点 | 原因 | 建议修复思路 |
|---|---|---|---|
| `catering-modules/catering-front/.../CiticQueryHandle.java` | 24/25 两处 `Long.parseLong(totalPageStr)` 未处理非整数、溢出或负数 | 非整数/溢出会直接抛 `NumberFormatException`，不会由 `FrontQueryDispatchNode` 的 `FrontException` 分支收口；负数会形成 `code=200` 且分页为负数 | 提取局部 `parseRequiredTotalPage`：捕获 `NumberFormatException`，校验值 `>= 0`，非法时抛 `FrontException(WALLET_RESPONSE_INVALID, ...)`；由现有 LiteFlow 失败链生成固定失败分页结果 |
| `catering-modules/catering-web-test/.../FrontTestController.java` | `callFeignTable()` 的 `FeignException` 兜底只设置 `code/msg` | `totalPage` 是 `Long`，新建对象未赋值时仍返回 `null`，与页面联调使用的固定分页壳不一致 | 在该兜底局部补 `total=0L`、`totalPage=0L`；`rows` 保持默认空列表 |

本轮确认没有发现新的 24/25 映射或路由问题；退款任务不在本 Issue 范围内。
本轮只做静态检查，未编译、未运行测试、未 commit/push，状态保持 `OPEN`。

## 修复实施与静态复核（2026-08-19）

1. `CiticQueryHandle` 新增局部 `parseRequiredTotalPage`，24/25 共用：
   - 缺失/空值 → `WALLET_RESPONSE_INVALID`；
   - 非整数或超出 `Long` → `WALLET_RESPONSE_INVALID`；
   - 负数或按银行页大小估算 `total` 会溢出 → `WALLET_RESPONSE_INVALID`；
2. `FrontTestController.callFeignTable()` 的 Feign 失败壳已补
   `total=0L`、`totalPage=0L`，`rows` 使用 `TableDataInfo` 默认空列表；
3. grep 确认两处明细路径不再直接执行 `Long.parseLong(totalPageStr)`；
4. `git diff --check` 通过。

未新增测试类，未运行测试、未编译、未 commit/push。4 条验收标准已获静态证据，
状态改为 `FIXED_PENDING_REVIEW`，等待用户确认后关闭。
