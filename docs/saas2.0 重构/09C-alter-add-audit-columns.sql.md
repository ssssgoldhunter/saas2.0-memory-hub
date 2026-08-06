# ALTER SQL：添加 create_by/create_time/update_by/update_time 审计列

> 用途：10 张渠道交易表已建表（有 `created_at`/`updated_at` 列），现改为用父类 BaseEntity 的
> `create_by`/`create_time`/`update_by`/`update_time` 4 个审计字段。
> 本 SQL 由用户手动在目标数据库执行。
> 生成日期：2026-08-05
> 目标字符集：utf8mb4 / utf8mb4_general_ci

---

## 1. 变更说明

### 1.1 为什么改

Entity 继承 `TenantEntity`（→ `BaseEntity`），BaseEntity 提供了 4 个审计字段：
- `createBy`（String）→ 列 `create_by`，`@TableField(fill = FieldFill.INSERT)`
- `createTime`（Date）→ 列 `create_time`，`@TableField(fill = FieldFill.INSERT)`
- `updateBy`（String）→ 列 `update_by`，`@TableField(fill = FieldFill.INSERT_UPDATE)`
- `updateTime`（Date）→ 列 `update_time`，`@TableField(fill = FieldFill.INSERT_UPDATE)`

MyBatis-Plus 的 `MetaObjectHandler` 会在 insert/update 时自动填充这 4 个字段。原来表只有
`created_at`/`updated_at`（对应 Entity 的 `createdAt`/`updatedAt`），现在统一改用父类审计字段，
所以表结构要同步调整。

### 1.2 变更内容

每张表：
- **删除** `created_at`、`updated_at` 两列（连同相关的索引 `idx_front_status_time`、`idx_front_store_time`）
- **新增** `create_by` VARCHAR(64)、`create_time` DATETIME、`update_by` VARCHAR(64)、`update_time` DATETIME 4 列
- **重建** `idx_front_status_time`（用 `update_time` 替代 `updated_at`）、`idx_front_store_time`（用 `create_time` 替代 `created_at`）

### 1.3 数据迁移

如果表里**已有数据**，`created_at`/`updated_at` 的值需要迁移到 `create_time`/`update_time`。
本 SQL 提供两个版本：
- **版本 A（表为空或数据可丢）**：直接 DROP 旧列 + ADD 新列
- **版本 B（表有数据需保留）**：先 ADD 新列 → UPDATE 迁移数据 → DROP 旧索引 → 重建索引 → DROP 旧列

**默认提供版本 B**（安全），如果表是空的可以简化为版本 A（注释里有说明）。

---

## 2. 完整 ALTER SQL（版本 B，保留数据）

```sql
-- =============================================================================
-- Front 渠道交易表审计字段变更：created_at/updated_at → create_by/create_time/update_by/update_time
-- 共 10 张表，每张表执行相同模式的 ALTER
-- 字符集：utf8mb4 / utf8mb4_general_ci
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. front_citic_transfer_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_transfer_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

-- 数据迁移（如果表为空可跳过这几行 UPDATE）
UPDATE `front_citic_transfer_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_transfer_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

-- 删除引用旧列的索引
ALTER TABLE `front_citic_transfer_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_transfer_transaction` DROP INDEX `idx_front_store_time`;

-- 重建索引（用新列）
ALTER TABLE `front_citic_transfer_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);

-- 删除旧列
ALTER TABLE `front_citic_transfer_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_transfer_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 2. front_pingan_transfer_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_pingan_transfer_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_pingan_transfer_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_pingan_transfer_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_pingan_transfer_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_transfer_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_transfer_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_pingan_transfer_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_transfer_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 3. front_citic_consume_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_consume_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_citic_consume_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_consume_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_citic_consume_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_consume_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_consume_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_citic_consume_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_consume_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 4. front_pingan_consume_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_pingan_consume_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_pingan_consume_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_pingan_consume_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_pingan_consume_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_consume_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_consume_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_pingan_consume_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_consume_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 5. front_citic_refund_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_refund_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_citic_refund_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_refund_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_citic_refund_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_refund_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_refund_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_citic_refund_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_refund_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 6. front_pingan_refund_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_pingan_refund_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_pingan_refund_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_pingan_refund_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_pingan_refund_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_refund_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_refund_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_pingan_refund_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_refund_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 7. front_citic_withdraw_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_withdraw_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_citic_withdraw_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_withdraw_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_citic_withdraw_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_withdraw_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_withdraw_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_citic_withdraw_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_withdraw_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 8. front_pingan_withdraw_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_pingan_withdraw_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_pingan_withdraw_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_pingan_withdraw_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_pingan_withdraw_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_withdraw_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_withdraw_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_pingan_withdraw_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_withdraw_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 9. front_citic_platform_pay_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_platform_pay_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_citic_platform_pay_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_platform_pay_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_citic_platform_pay_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_platform_pay_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_platform_pay_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_citic_platform_pay_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_platform_pay_transaction` DROP COLUMN `updated_at`;


-- -----------------------------------------------------------------------------
-- 10. front_citic_platform_receive_transaction
-- -----------------------------------------------------------------------------
ALTER TABLE `front_citic_platform_receive_transaction`
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`;

UPDATE `front_citic_platform_receive_transaction` SET `create_time` = `created_at` WHERE `created_at` IS NOT NULL;
UPDATE `front_citic_platform_receive_transaction` SET `update_time` = `updated_at` WHERE `updated_at` IS NOT NULL;

ALTER TABLE `front_citic_platform_receive_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_platform_receive_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_platform_receive_transaction`
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);
ALTER TABLE `front_citic_platform_receive_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_platform_receive_transaction` DROP COLUMN `updated_at`;
```

---

## 3. 简化版（表为空时用）

如果 10 张表都是空的（刚建表没数据），可以跳过数据迁移的 UPDATE，直接：

```sql
-- 对每张表执行（以 front_citic_transfer_transaction 为例）：
ALTER TABLE `front_citic_transfer_transaction`
  DROP INDEX `idx_front_status_time`,
  DROP INDEX `idx_front_store_time`,
  DROP COLUMN `created_at`,
  DROP COLUMN `updated_at`,
  ADD COLUMN `create_by`   VARCHAR(64) DEFAULT NULL COMMENT '创建者' AFTER `front_remark`,
  ADD COLUMN `create_time` DATETIME    DEFAULT NULL COMMENT '创建时间' AFTER `create_by`,
  ADD COLUMN `update_by`   VARCHAR(64) DEFAULT NULL COMMENT '更新者' AFTER `send_started_at`,
  ADD COLUMN `update_time` DATETIME    DEFAULT NULL COMMENT '更新时间' AFTER `update_by`,
  ADD KEY `idx_front_status_time` (`tenant_id`, `front_status`, `update_time`),
  ADD KEY `idx_front_store_time` (`tenant_id`, `store_id`, `create_time`);

-- 其余 9 张表同理，替换表名即可
```

---

## 4. 字段位置说明

`AFTER` 子句控制新列的物理位置：

| 新列 | AFTER | 含义 |
|---|---|---|
| `create_by` | `front_remark` | 紧跟 front_remark 之后 |
| `create_time` | `create_by` | 紧跟 create_by 之后 |
| `update_by` | `send_started_at` | 紧跟 send_started_at 之前（审计字段分两组：create 组在 front_remark 后，update 组在时间字段区） |
| `update_time` | `update_by` | 紧跟 update_by 之后 |

最终字段顺序（相关段）：
```
... front_remark, create_by, create_time, send_started_at, update_by, update_time,
bank_responded_at, completed_at, version
```

注意：`create_by`/`create_time` 放在 `front_remark` 后（业务字段结束后）；`update_by`/`update_time`
放在 `send_started_at` 前。这样审计字段不会和业务时间字段（sendStartedAt/bankRespondedAt/completedAt）
混在一起。如果你希望审计字段都放在一起（比如都在 version 前），告诉我调整 AFTER 子句。

---

## 5. 执行后自检

```sql
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
  AND COLUMN_NAME IN ('create_by', 'create_time', 'update_by', 'update_time', 'created_at', 'updated_at')
ORDER BY TABLE_NAME, COLUMN_NAME;
```

预期：返回 40 行（10 表 × 4 新列），`created_at`/`updated_at` 不再出现。

索引核查：
```sql
SELECT TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
  AND INDEX_NAME IN ('idx_front_status_time', 'idx_front_store_time')
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;
```

预期：`idx_front_status_time` 第 3 列是 `update_time`；`idx_front_store_time` 第 3 列是 `create_time`。

---

## 6. 仅删除旧列（created_at / updated_at）

如果只需要去掉 `created_at`/`updated_at` 两列（不加新列、不重建索引），执行以下 SQL。

**注意**：`idx_front_status_time`/`idx_front_store_time` 两个索引引用了 `updated_at`/`created_at` 列，
必须**先删索引、再删列**，否则 DROP COLUMN 会因索引依赖失败。本 SQL 已按此顺序编排。
删完这两个索引后，如果后续不需要按状态/门店+时间查询，可以不重建；如需保留查询能力，应执行
§2/§3 中重建索引到 `update_time`/`create_time` 的部分（前提是已先 ADD 了这两列）。

```sql
-- =============================================================================
-- 仅删除 10 张表的 created_at / updated_at 列（含先删依赖索引）
-- 不加新列、不重建索引
-- =============================================================================

-- 1. front_citic_transfer_transaction
ALTER TABLE `front_citic_transfer_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_transfer_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_transfer_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_transfer_transaction` DROP COLUMN `updated_at`;

-- 2. front_pingan_transfer_transaction
ALTER TABLE `front_pingan_transfer_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_transfer_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_transfer_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_transfer_transaction` DROP COLUMN `updated_at`;

-- 3. front_citic_consume_transaction
ALTER TABLE `front_citic_consume_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_consume_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_consume_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_consume_transaction` DROP COLUMN `updated_at`;

-- 4. front_pingan_consume_transaction
ALTER TABLE `front_pingan_consume_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_consume_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_consume_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_consume_transaction` DROP COLUMN `updated_at`;

-- 5. front_citic_refund_transaction
ALTER TABLE `front_citic_refund_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_refund_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_refund_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_refund_transaction` DROP COLUMN `updated_at`;

-- 6. front_pingan_refund_transaction
ALTER TABLE `front_pingan_refund_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_refund_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_refund_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_refund_transaction` DROP COLUMN `updated_at`;

-- 7. front_citic_withdraw_transaction
ALTER TABLE `front_citic_withdraw_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_withdraw_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_withdraw_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_withdraw_transaction` DROP COLUMN `updated_at`;

-- 8. front_pingan_withdraw_transaction
ALTER TABLE `front_pingan_withdraw_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_pingan_withdraw_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_pingan_withdraw_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_pingan_withdraw_transaction` DROP COLUMN `updated_at`;

-- 9. front_citic_platform_pay_transaction
ALTER TABLE `front_citic_platform_pay_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_platform_pay_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_platform_pay_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_platform_pay_transaction` DROP COLUMN `updated_at`;

-- 10. front_citic_platform_receive_transaction
ALTER TABLE `front_citic_platform_receive_transaction` DROP INDEX `idx_front_status_time`;
ALTER TABLE `front_citic_platform_receive_transaction` DROP INDEX `idx_front_store_time`;
ALTER TABLE `front_citic_platform_receive_transaction` DROP COLUMN `created_at`;
ALTER TABLE `front_citic_platform_receive_transaction` DROP COLUMN `updated_at`;
```

### 6.1 删除后自检

```sql
SELECT TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
  AND COLUMN_NAME IN ('created_at', 'updated_at')
ORDER BY TABLE_NAME, COLUMN_NAME;
```

预期：返回 0 行（两列已彻底移除）。

```sql
SELECT TABLE_NAME, INDEX_NAME
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME LIKE 'front\_%\_transaction'
  AND INDEX_NAME IN ('idx_front_status_time', 'idx_front_store_time')
GROUP BY TABLE_NAME, INDEX_NAME
ORDER BY TABLE_NAME, INDEX_NAME;
```

预期：返回 0 行（两个索引随旧列一起删除）。如需保留状态/门店+时间查询能力，需先 ADD
`create_time`/`update_time` 列后重建这两个索引（见 §2 或 §3）。
