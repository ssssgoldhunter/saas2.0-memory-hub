-- 中信退款表历史兼容列放宽非空约束
-- 适用范围：已存在 front_citic_refund_transaction 的 MySQL 环境
-- 边界：不删列、不删索引、不修改数据，不影响平安退款表
-- 分库环境：每个实际承载该表的 ds_x 物理数据库都需单独执行一次
-- 当前中信 Handle 不读写以下五列；实际原交易定位使用
-- original_biz_order_no + original_biz_sub_order_no。

ALTER TABLE `front_citic_refund_transaction`
  MODIFY COLUMN `original_capability` VARCHAR(20) NULL DEFAULT NULL
    COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  MODIFY COLUMN `original_channel_transaction_id` BIGINT NULL DEFAULT NULL
    COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  MODIFY COLUMN `original_front_ssn` VARCHAR(100) NULL DEFAULT NULL
    COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  MODIFY COLUMN `original_biz_transaction_id` VARCHAR(100) NULL DEFAULT NULL
    COMMENT '兼容保留列；中信当前退款路径不使用且不回填',
  MODIFY COLUMN `original_biz_sub_transaction_id` VARCHAR(100) NULL DEFAULT NULL
    COMMENT '兼容保留列；中信当前退款路径不使用且不回填';
