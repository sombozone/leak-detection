-- 最小流量基准系统演示脚本
-- 展示如何使用基于配置的基准计算系统

-- ========================================
-- 1. 查看配置信息
-- ========================================

-- 查看所有配置
SELECT 
    config_name,
    config_description,
    calculation_period,
    tolerance_percentage,
    calculation_method,
    is_active
FROM "leak_detection".mnf_baseline_config
ORDER BY is_active DESC, created_at;

-- ========================================
-- 2. 查看区域和配置关联信息
-- ========================================

-- 查看区域和配置关联数据
SELECT 
    d.name as district_name,
    c.config_name,
    c.config_description,
    dc.priority,
    dc.is_active,
    c.calculation_period,
    c.calculation_method,
    c.tolerance_percentage
FROM "leak_detection".mnf_baseline_district_config dc
JOIN "leak_detection".mnf_baseline_config c ON dc.config_id = c.id
JOIN "leak_detection".district d ON dc.district_id = d.id
WHERE dc.is_active = TRUE
ORDER BY d.id, dc.priority;

-- ========================================
-- 3. 测试配置获取函数
-- ========================================

-- 获取城南分区的配置（应该返回敏感配置）
SELECT * FROM "leak_detection".get_baseline_config(1);

-- 获取城北分区的配置（应该返回稳定配置）
SELECT * FROM "leak_detection".get_baseline_config(2);

-- 获取蒲纺分区的配置（应该返回平均值配置）
SELECT * FROM "leak_detection".get_baseline_config(3);

-- 获取默认配置（不指定分区）
SELECT * FROM "leak_detection".get_baseline_config();

-- ========================================
-- 4. 计算基准数据（使用区域特定配置）
-- ========================================

-- 为城南分区计算基准数据（使用敏感配置）
SELECT * FROM "leak_detection".calculate_mnf_baseline(1, '2024-01-08');

-- 为城北分区计算基准数据（使用稳定配置）
SELECT * FROM "leak_detection".calculate_mnf_baseline(2, '2024-01-08');

-- 为蒲纺分区计算基准数据（使用平均值配置）
SELECT * FROM "leak_detection".calculate_mnf_baseline(3, '2024-01-08');

-- ========================================
-- 5. 计算基准数据（使用特定配置覆盖）
-- ========================================

-- 获取配置ID
DO $$
DECLARE
    v_default_config_id UUID;
    v_sensitive_config_id UUID;
    v_stable_config_id UUID;
    v_average_config_id UUID;
BEGIN
    -- 获取配置ID
    SELECT id INTO v_default_config_id FROM "leak_detection".mnf_baseline_config WHERE config_name = 'DEFAULT_CONFIG';
    SELECT id INTO v_sensitive_config_id FROM "leak_detection".mnf_baseline_config WHERE config_name = 'SENSITIVE_CONFIG';
    SELECT id INTO v_stable_config_id FROM "leak_detection".mnf_baseline_config WHERE config_name = 'STABLE_CONFIG';
    SELECT id INTO v_average_config_id FROM "leak_detection".mnf_baseline_config WHERE config_name = 'AVERAGE_CONFIG';
    
    -- 使用默认配置覆盖所有分区
    RAISE NOTICE '使用默认配置覆盖所有分区:';
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(1, '2024-01-08', v_default_config_id);
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(2, '2024-01-08', v_default_config_id);
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(3, '2024-01-08', v_default_config_id);
    
    RAISE NOTICE '使用敏感配置覆盖所有分区:';
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(1, '2024-01-08', v_sensitive_config_id);
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(2, '2024-01-08', v_sensitive_config_id);
    PERFORM * FROM "leak_detection".calculate_mnf_baseline(3, '2024-01-08', v_sensitive_config_id);
END $$;

-- ========================================
-- 6. 插入基准数据到数据库
-- ========================================

-- 为所有分区插入基准数据（使用各自的区域配置）
SELECT * FROM "leak_detection".calculate_all_districts_baseline('2024-01-08');

-- 查看插入的基准数据
SELECT 
    district_name,
    baseline_date,
    config_name,
    calculation_period,
    calculation_method,
    tolerance_percentage,
    baseline_mnf_value,
    upper_threshold,
    lower_threshold,
    data_count,
    data_quality_flag,
    comments
FROM "leak_detection".mnf_baseline b
JOIN "leak_detection".mnf_baseline_config c ON b.config_id = c.id
WHERE b.is_active = TRUE
ORDER BY b.district_id, b.baseline_date;

-- ========================================
-- 7. 创建视图用于日常查询
-- ========================================

-- 创建基准数据汇总视图
CREATE OR REPLACE VIEW "leak_detection".v_mnf_baseline_summary AS
SELECT 
    b.district_id,
    b.district_name,
    b.baseline_date,
    c.config_name,
    c.config_description,
    b.calculation_period,
    b.calculation_method,
    b.tolerance_percentage,
    b.baseline_mnf_value,
    b.baseline_mnf_ratio,
    b.upper_threshold,
    b.lower_threshold,
    b.data_count,
    b.data_quality_flag,
    b.comments,
    b.created_at
FROM "leak_detection".mnf_baseline b
JOIN "leak_detection".mnf_baseline_config c ON b.config_id = c.id
WHERE b.is_active = TRUE
ORDER BY b.district_id, b.baseline_date DESC;

-- 创建基准数据与日常数据对比视图
CREATE OR REPLACE VIEW "leak_detection".v_mnf_daily_vs_baseline AS
SELECT 
    r.district_id,
    r.district_name,
    r.record_date,
    r.mnf_cumulative_value as daily_mnf,
    r.mnf_ratio as daily_mnf_ratio,
    b.baseline_mnf_value,
    b.baseline_mnf_ratio,
    b.upper_threshold,
    b.lower_threshold,
    c.config_name,
    c.calculation_method,
    CASE 
        WHEN r.mnf_cumulative_value > b.upper_threshold THEN 'ABOVE_THRESHOLD'
        WHEN r.mnf_cumulative_value < b.lower_threshold THEN 'BELOW_THRESHOLD'
        ELSE 'NORMAL'
    END as threshold_status,
    ROUND(((r.mnf_cumulative_value - b.baseline_mnf_value) / b.baseline_mnf_value * 100)::DECIMAL(5,2), 2) as deviation_percentage,
    r.data_quality_flag,
    r.anomaly_flag
FROM "leak_detection".mnf_daily_record r
LEFT JOIN "leak_detection".mnf_baseline b ON r.district_id = b.district_id 
    AND b.is_active = TRUE
    AND b.baseline_date <= r.record_date
    AND b.baseline_date = (
        SELECT MAX(b2.baseline_date) 
        FROM "leak_detection".mnf_baseline b2 
        WHERE b2.district_id = r.district_id 
          AND b2.is_active = TRUE 
          AND b2.baseline_date <= r.record_date
    )
LEFT JOIN "leak_detection".mnf_baseline_config c ON b.config_id = c.id
ORDER BY r.district_id, r.record_date DESC;

-- ========================================
-- 8. 演示查询
-- ========================================

-- 查看基准数据汇总
SELECT * FROM "leak_detection".v_mnf_baseline_summary;

-- 查看基准数据与日常数据对比
SELECT * FROM "leak_detection".v_mnf_daily_vs_baseline;

-- 查看异常数据
SELECT 
    district_name,
    record_date,
    daily_mnf,
    baseline_mnf_value,
    threshold_status,
    deviation_percentage
FROM "leak_detection".v_mnf_daily_vs_baseline 
WHERE threshold_status != 'NORMAL'
ORDER BY district_id, record_date;

-- 查看不同配置方法的效果对比
SELECT 
    district_name,
    config_name,
    calculation_method,
    baseline_mnf_value,
    upper_threshold,
    lower_threshold,
    data_count,
    data_quality_flag
FROM "leak_detection".v_mnf_baseline_summary
WHERE baseline_date = '2024-01-08'
ORDER BY district_id;

-- ========================================
-- 9. 配置管理示例
-- ========================================

-- 查看配置使用情况
SELECT 
    c.config_name,
    COUNT(b.id) as baseline_count,
    MAX(b.baseline_date) as latest_baseline_date
FROM "leak_detection".mnf_baseline_config c
LEFT JOIN "leak_detection".mnf_baseline b ON c.id = b.config_id AND b.is_active = TRUE
GROUP BY c.id, c.config_name
ORDER BY baseline_count DESC, c.config_name;

-- 查看区域配置分配情况
SELECT 
    d.name as district_name,
    c.config_name,
    dc.priority,
    dc.is_active,
    c.calculation_period,
    c.calculation_method
FROM "leak_detection".mnf_baseline_district_config dc
JOIN "leak_detection".mnf_baseline_config c ON dc.config_id = c.id
JOIN "leak_detection".district d ON dc.district_id = d.id
WHERE dc.is_active = TRUE
ORDER BY d.id, dc.priority;

-- ========================================
-- 10. 区域配置管理示例
-- ========================================

-- 为新区分配配置
DO $$
DECLARE
    v_default_config_id UUID;
BEGIN
    -- 获取默认配置ID
    SELECT id INTO v_default_config_id FROM "leak_detection".mnf_baseline_config WHERE config_name = 'DEFAULT_CONFIG';
    
    -- 假设有新区ID为4，为其分配默认配置
    INSERT INTO "leak_detection".mnf_baseline_district_config (
        config_id, district_id, priority, is_active, comments
    ) VALUES (
        v_default_config_id, 4, 1, TRUE, '新区使用默认配置'
    ) ON CONFLICT (config_id, district_id) DO NOTHING;
    
    RAISE NOTICE '已为新区分配默认配置';
END $$;

-- 修改区域配置优先级
UPDATE "leak_detection".mnf_baseline_district_config
SET priority = 2, comments = '优先级调整为2'
WHERE district_id = 1 AND config_name = 'DEFAULT_CONFIG';

-- 查看修改后的配置
SELECT 
    d.name as district_name,
    c.config_name,
    dc.priority,
    dc.is_active,
    dc.comments
FROM "leak_detection".mnf_baseline_district_config dc
JOIN "leak_detection".mnf_baseline_config c ON dc.config_id = c.id
JOIN "leak_detection".district d ON dc.district_id = d.id
WHERE dc.is_active = TRUE
ORDER BY d.id, dc.priority;

-- ========================================
-- 11. 配置切换示例
-- ========================================

-- 切换到敏感配置（全局）
DO $$
DECLARE
    v_sensitive_config_id UUID;
BEGIN
    -- 获取敏感配置ID
    SELECT id INTO v_sensitive_config_id
    FROM "leak_detection".mnf_baseline_config
    WHERE config_name = 'SENSITIVE_CONFIG';
    
    -- 为所有分区使用敏感配置计算基准数据
    PERFORM * FROM "leak_detection".calculate_all_districts_baseline('2024-01-08', v_sensitive_config_id);
    
    RAISE NOTICE '已切换到敏感配置并重新计算基准数据';
END $$;

-- 查看切换后的效果
SELECT 
    district_name,
    config_name,
    calculation_period,
    tolerance_percentage,
    baseline_mnf_value,
    upper_threshold,
    lower_threshold
FROM "leak_detection".v_mnf_baseline_summary
WHERE baseline_date = '2024-01-08'
ORDER BY district_id; 