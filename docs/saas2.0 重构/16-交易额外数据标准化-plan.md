# 交易额外数据标准化执行计划

> 前置阅读：[15-交易额外数据标准化-spec.md](15-交易额外数据标准化-spec.md)（契约与矩阵的唯一事实来源，本计划只排顺序，不重复定义）
> 纪律：每阶段结束跑一次编译，红了先修再进下一阶段；除标注外不新增测试；所有新代码注释密度与现有代码一致
> 范围提醒：front 交易链（front-flow.xml / 两个 TransactionHandle / 三个交易 baseData 类）**零改动**——见 spec §6

## Phase 0 基线确认（只读）

1. `mvn compile -pl catering-api/catering-api-front,catering-modules/catering-front -am -DskipTests` → BUILD SUCCESS（2026-08-17 已验证）；
2. `cd catering-modules/catering-web-test && mvn compile -DskipTests` → BUILD SUCCESS；
3. 通读 spec §3/§4/§5/§6，确认理解：组装是 front 暴露的独立 API，由 catering-consume 调用；pay/rec 命名红线；13 绑定矩阵；交易链零改动。

## Phase 1 api-front 模型与 API 契约（纯新增 + 一处改名）

1. 新建模型（`com.chinaums.front.api.model.request` / `.response`）：
   `FrontAccountInfo`、`FrontBankCard`、`AuthInfo`（字段见 spec §3.2，@Data + @Schema 风格对齐同包）；
2. 新建 `AssembleSpecialDataRequest extends BaseRequest`（capability/pay/rec/oriPay/oriRec/auth/originalBusinessDate/contractId）与 `SpecialDataAssembleResult{JSONObject specialData}`；
3. 新建 Feign 接口 `FrontAssembleApi`（`POST /front/v1/assemble/special-data`，spec §5.1）；
4. `AuthTransferBusinessData` 改名 `AuthBusinessData`：改类名+文件名，全库更新引用（grep 确认：FrontTransactionApi、FrontTransactionController、FrontTransactionApplicationService、BankTransactionHandle、PingAnTransactionHandle、FrontRequestValidateNode、FrontInvocationLogAspect 等）；
5. 编译。

## Phase 2 front 组装器层（纯新增）

1. 新建包 `com.chinaums.front.channel.assemble`：`SpecialDataAssembler` 接口、`SpecialDataAssemblerRegistry`（注册/查找不到行为对齐 `TransactionHandleRegistry`，复用 `BankCapabilityKey`）；
2. 按 spec §4 矩阵实现 13 个绑定（建议先写中信 TRANSFER 作样板，再横向铺开）：
   - 中信：Transfer、Consume、Withdraw、Refund、PlatformPay、PlatformReceive；
   - 平安：Transfer、Consume、TransferAuth、TransferAuthCodeResend、Withdraw、Refund（空实现，返回空 JSONObject）；
   - 键名全部走 `*ContractKeys` 常量；缺字段抛 `FrontException(INVALID_REQUEST)`，消息如 `pay.bankEAccountId不能为空`；`originalBusinessDate` 的 yyyyMMdd 校验在组装器内；
   - 中信 TRANSFER/CONSUME 映射相同：共用抽象父类或一类双绑定均可；
3. 编译。

## Phase 3 front 组装 API 三层

1. `FrontAssembleController implements FrontAssembleApi`（@RequestMapping 路径与 API 一致，对齐 FrontTransactionController 的实现方式）；
2. `FrontAssembleApplicationService`：platformCode→BankCode.fromCode() → registry.get(bankCode, capability).assemble(request) → 包装 `R.ok(SpecialDataAssembleResult)`；不进 LiteFlow、不查配置、不调银行；
3. 类注释写明：纯静态映射、幂等、交易报文加密仍发生在交易链 Handle；
4. 编译。

## Phase 4 交易链零改动确认（只读验证）

1. `git status` / `git diff` 确认：front-flow.xml、CiticTransactionHandle、PingAnTransactionHandle、BaseTransactionBusinessData、RefundBusinessData、PlatformTransferBusinessData 均无改动；
2. `grep -rn "requireSpecialData" *TransactionHandle.java` 应保持原样（这是直传协议键的最后防线，**不得删除**）。

## Phase 5 web-test 两步调用改造

1. `FrontTestController` 新增端点 `POST /assemble/special-data`（透传 FrontAssembleApi，沿用 callFeign 模式与结构化日志）；
2. `static/js/app.js`：
   - 账户下拉产出标准结构：accountNo→bankEAccountId、name→bankAccountName、bankCardNo→pay.bankCard.bankCardNo；平台付款只填 rec、平台收款只填 pay；提现填 pay+bankCard；退款填 oriPay/oriRec + originalBusinessDate；鉴权填 auth={authOrderNo,authCode}；平台收付 contractId 选填；
   - 交易 Tab 提交流程改为两步：先调组装端点展示/取得 specialData → 组装进交易请求 → 调交易端点；查询 Tab 不变；
3. `static/index.html`：鉴权 Tab 加 authOrderNo/authCode 输入；退款 Tab 加 originalBusinessDate（yyyyMMdd）；平台收付 Tab 加 contractId（选填）；交易 Tab 增加组装结果展示区；
4. web-test 单独编译 + 启动冒烟（8 个交易 Tab 走两步、5 个查询 Tab 行为不变）。

## Phase 6 文档同步（按 spec §9 清单）

13（组装 API 登记）、05（组装 API 章节 + 双层口径，"specialData 协议原始名"条款保留）、
06/07/08（头部加注指向 15 号）、14（web-test 两步调用说明）、WIKI-START（如条目描述需微调）、
12-issues P1-002 补充关闭注记。

## Phase 7 终验（spec §11 全量自检）

1. 三模块编译绿；
2. `git diff` 证明交易链六文件零改动（spec §11.2）；
3. 组装器绑定数 13、无字面量协议键、payer/payee 零命中；
4. web-test 两步冒烟通过；
5. 输出执行报告：每 Phase 实际改动文件清单 + 自检结果，交用户复核。

## catering-consume 侧（业务侧实施，不在本计划编译范围）

按 spec §7 契约执行：flow 加组装 check 节点 → Feign 调 FrontAssembleApi → 校验注入交易请求 → 失败即终止不降级。由业务侧团队或后续单独任务领取，front 侧 Phase 1-7 完成即可联调。

## 回滚策略

Phase 1-3 全部纯新增（除 AuthBusinessData 改名），可整体 revert，不影响任何存量行为；
web-test 改造独立 revert。本方案不存在行为切换点（交易链未动），风险面为历史最低。
