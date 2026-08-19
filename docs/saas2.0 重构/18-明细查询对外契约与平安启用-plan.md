# 明细查询对外契约与平安启用执行计划（18 号）

> 前置阅读：[17-明细查询对外契约与平安启用-spec.md](17-明细查询对外契约与平安启用-spec.md)（契约唯一事实来源，
> §0 八条裁决 + §1.3 迁移对照表）
> 原始溯源：`/Users/limeng/WorkBuddy/钱包功能/文档/中信24_25明细查询_平安对齐映射表.md`（v6.10，字段级论证）
> 纪律：每阶段编译；不新增测试；所有裁决以 17 号 §0 八条为准，与对齐表冲突时以 17 号为准

## 任务清单（执行 AI 按序领取，完成后打勾并在 16 号风格记录实际改动）

- [ ] T1 Phase 1：AccountDetailItem / PlatformDetailItem 新建 + TableDataInfo.totalPage + API 三层泛型替换 + TransactionDetailItem 删除（按 17 号 §1.2/§1.3）
- [ ] T2 Phase 2：组装器 24/25 枚举白名单收窄（{04} / {01,02,03}），Handle 白名单不动
- [ ] T3 Phase 3：中信 queryTransactionDetails 改产 AccountDetailItem（fee×100、查表无关、specialData 兜底）
- [ ] T4 Phase 3：中信 queryPlatformTransactionDetails 改产 PlatformDetailItem（02/03 中信侧字段自然空）
- [ ] T5 Phase 3：中信 TableDataInfo 赋值（TOTAL_PAGE 直传 + total=页大小估算）
- [ ] T6 Phase 4：平安 queryTransactionDetails 实现（6073：functionFlag/subAcctNo/queryFlag=2/tranStatus 过滤/commission→fee=0 不过滤/frontSeqNo 查表补订单号）
- [ ] T7 Phase 4：平安 queryPlatformTransactionDetails 实现（6050/6048 类型分流 + SM2 解密三连 + inAcctType 过滤回填 + termSsn + 分页三态）
- [ ] T8 Phase 4：移除两个明细方法 pendingIntegration（账户状态/余额保留挡板）
- [ ] T9 Phase 5：web-test 两明细 Tab 类型下拉收窄 + 返回文案
- [ ] T10 Phase 6：文档同步（10/13/15/16/05/TODO-001/WIKI-START）
- [ ] T11 Phase 7：17 号 §8 七条自检 + 执行报告（含编译证据）

## Phase 0 基线（只读）

1. 四模块编译绿（api-front/front/consume/web-test，api-front 需先 install 到 /Users/limeng/shares/m2saas）；
2. 通读 17 号 spec §0-§4 与对齐表第十/十六/十八/二十/二十二章。

## Phase 1 api-front 契约层

1. 新建 `model/response/AccountDetailItem.java`（11 主字段 + specialData，字段表 17 号 §1.2；fee 为 Long 分）；
2. 新建 `model/response/PlatformDetailItem.java`（12 主字段 + specialData，transAmt 为 Long 分）；
3. `TableDataInfo` 增加 `totalPage` 字段（保持既有 total 语义不变，补 javadoc）；
4. `FrontQueryApi`/Controller/ApplicationService 两个明细方法泛型改为新 DTO
   （`TableDataInfo<AccountDetailItem>` / `TableDataInfo<PlatformDetailItem>`），javadoc 同步；
5. `TransactionDetailItem` 确认无其他引用后删除（编译器兜底）；
6. 编译。

## Phase 2 组装器白名单收窄

1. `CiticSpecialDataAssembler`：24 格枚举 {04}、25 格枚举 {01,02,03}（错误消息同步对外口径）；
   `accountType` 选填白名单不动；
2. Handle 层（CiticQueryHandle）白名单**保持全量不动**——Phase 4 只验证不修改；
3. 编译。

## Phase 3 中信 Handle 改造

1. `queryTransactionDetails`（24）：parse 产出 `AccountDetailItem`（USER_ID/USER_NAME/REQ_JRN/
   TRANS_AMT×100→fee/TRANS_DT/TRANS_TM/MCHNT_ORDER_ID/SUB_ID + specialData 兜底：MCHNT_ID/C_D_FLAG/
   CUR_AMT/GOAC/OANM/DIGEST/REGISTER_SSN 等）；
2. `queryPlatformTransactionDetails`（25）：parse 产出 `PlatformDetailItem`（含 02/03 类型中信侧
   USER_NM/USER_ID/REARK2 自然为空）；transType 回填 01/02/03；
3. TableDataInfo 赋值：TOTAL_PAGE 直传 + total=TOTAL_PAGE×页大小估算（24×50、25×20）；
4. 分页透传：不做任何对齐（17 号 §0.8）；
5. 编译。

## Phase 4 平安 Handle 实现（TODO-001 明细两项启用）

1. 移除 `queryTransactionDetails`/`queryPlatformTransactionDetails` 的 `pendingIntegration()`
   （账户状态/余额两个保留挡板）；
2. 24-04 → 6073（bizFunc=08）：请求 functionFlag（当日 1 不传 begin/end / 历史 2 + begin=end）+
   subAcctNo=acctNo（SM2）+ queryFlag=2 + pageNum；返回：tranStatus=0 过滤、解密 subAcctNo/subAcctName、
   fee=commission 直传（分，空/0 → 0 不过滤）、frontTransSsn=frontSeqNo、bizOrderNo/bizSubOrderNo 以
   frontSeqNo 查 front 渠道表（tenantId+银行流水号，参考 loadOriginalRefundFields 回查模式）查不到置空；
3. 25 类型分流：01/03 → 6050（bizFunc=04，共用请求，业务体无 inAcctType；functionFlag 当日/历史；
   page）+ 返回按 inAcctType 过滤回填 transType；02 → 6048（bizFunc=02，仅租户配置三件套，无日期无分页
   一次全返；frontSeqNo=**termSsn**（17 号 §0.6））；
4. 25 返回：解密（6050：subAcctNo/inAcctNo/inAcctName；6048：acctNo/cardNoEnc/nameEnc）、
   transDate（6050 accountingDate / 6048 returnDate）、transTime 置空（6048 的 userName 查表或空）、
   transAmt 直传分；
5. TableDataInfo：6050/6073 totalPage=ceil(totalNum/原生页大小)、total=totalNum；6048 totalPage=1、
   total=条数；
6. 编译 + 对照 17 号 §8 grep 自检（挡板 2 个保留、Handle 白名单全量）。

## Phase 5 web-test

两个明细 Tab 类型下拉收窄（24：04；25：01/02/03），两步组装流程不变；返回区文案更新为新 DTO 字段。

## Phase 6 文档同步

按 17 号 §6：10 号（§4/§5 重写 + 平安侧）、13 号（§5.4/§5.5 + §9 平安查询状态 4→2）、
15 号 §4.3（白名单修订）、13-front后续待办 TODO-001（明细两项转已启用）、05 号（挡板表述）、
16 号收盘记录、WIKI-START 注册 17/18 号。

## Phase 7 终验（17 号 §8 七条全量自检）+ 执行报告

## 回滚策略

Phase 1-2 为契约/白名单变更（有外部影响但当前无业务方，窗口期安全）；Phase 3-4 为 Handle 行为切换，
按能力小步提交可独立 revert；平安侧新增协议类纯增量。
