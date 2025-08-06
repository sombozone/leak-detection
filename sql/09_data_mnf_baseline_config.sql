-- 最小流量基准配置示例数据

-- 插入默认配置
INSERT INTO "leak_detection".mnf_baseline_config (
    config_name,
    config_description,
    calculation_period,
    tolerance_percentage,
    calculation_method,
    is_active,
    comments
) VALUES (
    'DEFAULT_CONFIG',
    '默认基准配置 - 适用于所有分区',
    10,                    -- 计算周期：10天
    10.00,                 -- 容差百分比：10%
    'MIN_OF_MIN',          -- 计算方法：最小值的最小值
    TRUE,                  -- 激活
    '系统默认配置，基于前10天最小流量的最小值计算基准'
);

-- 插入备用配置（更敏感）
INSERT INTO "leak_detection".mnf_baseline_config (
    config_name,
    config_description,
    calculation_period,
    tolerance_percentage,
    calculation_method,
    is_active,
    comments
) VALUES (
    'SENSITIVE_CONFIG',
    '敏感基准配置',
    7,                     -- 计算周期：7天（更敏感）
    8.00,                  -- 容差百分比：8%（更严格）
    'MIN_OF_MIN',          -- 计算方法：最小值的最小值
    FALSE,                 -- 非激活状态
    '敏感配置，采用更敏感的参数设置'
);

-- 插入稳定配置
INSERT INTO "leak_detection".mnf_baseline_config (
    config_name,
    config_description,
    calculation_period,
    tolerance_percentage,
    calculation_method,
    is_active,
    comments
) VALUES (
    'STABLE_CONFIG',
    '稳定基准配置',
    14,                    -- 计算周期：14天（更稳定）
    12.00,                 -- 容差百分比：12%（更宽松）
    'PERCENTILE_25',       -- 计算方法：25%分位数
    FALSE,                 -- 非激活状态
    '稳定配置，采用更稳定的参数设置'
);

-- 插入平均值配置
INSERT INTO "leak_detection".mnf_baseline_config (
    config_name,
    config_description,
    calculation_period,
    tolerance_percentage,
    calculation_method,
    is_active,
    comments
) VALUES (
    'AVERAGE_CONFIG',
    '平均值基准配置',
    10,                    -- 计算周期：10天
    10.00,                 -- 容差百分比：10%
    'AVERAGE',             -- 计算方法：平均值
    FALSE,                 -- 非激活状态
    '平均值配置，采用平均值计算方法'
);

-- 查看配置数据
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
-- 区域和基准配置关联示例数据
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
    
    -- 为城南分区分配敏感配置（优先级1）
    INSERT INTO "leak_detection".mnf_baseline_district_config (
        config_id, district_id, priority, is_active, comments
    ) VALUES (
        v_sensitive_config_id, 1, 1, TRUE, '城南分区使用敏感配置'
    );
    
    -- 为城北分区分配稳定配置（优先级1）
    INSERT INTO "leak_detection".mnf_baseline_district_config (
        config_id, district_id, priority, is_active, comments
    ) VALUES (
        v_stable_config_id, 2, 1, TRUE, '城北分区使用稳定配置'
    );
    
    -- 为蒲纺分区分配平均值配置（优先级1）
    INSERT INTO "leak_detection".mnf_baseline_district_config (
        config_id, district_id, priority, is_active, comments
    ) VALUES (
        v_average_config_id, 3, 1, TRUE, '蒲纺分区使用平均值配置'
    );
    
    -- 为城南分区添加备用配置（优先级2，作为备用）
    INSERT INTO "leak_detection".mnf_baseline_district_config (
        config_id, district_id, priority, is_active, comments
    ) VALUES (
        v_default_config_id, 1, 2, TRUE, '城南分区备用配置'
    );
    
    RAISE NOTICE '区域和配置关联数据已插入';
END $$;

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