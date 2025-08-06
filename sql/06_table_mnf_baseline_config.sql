-- 最小流量基准配置表
-- 用于管理基准计算的配置参数
CREATE TABLE IF NOT EXISTS "leak_detection".mnf_baseline_config (
    -- 主键：UUID类型（Supabase推荐）
    id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 配置标识
    config_name          TEXT NOT NULL UNIQUE,           -- 配置名称（如：'DEFAULT_CONFIG'）
    config_description   TEXT,                           -- 配置描述
    
    -- 计算参数配置
    calculation_period   INTEGER DEFAULT 10 NOT NULL,     -- 计算周期（天数，默认10天）
    tolerance_percentage DECIMAL(5,2) DEFAULT 10.00 NOT NULL, -- 容差百分比（默认10%）
    
    -- 计算方法配置
    calculation_method   TEXT DEFAULT 'MIN_OF_MIN' CHECK (
        calculation_method IN ('MIN_OF_MIN', 'AVERAGE', 'PERCENTILE_25', 'PERCENTILE_10')
    ) NOT NULL,                                          -- 计算方法
    
    -- 状态控制
    is_active            BOOLEAN DEFAULT TRUE,           -- 是否激活
    
    
    -- 备注信息
    comments             TEXT,                           -- 备注信息
    
    -- Supabase标准时间戳字段
    created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by           UUID REFERENCES auth.users(id)  -- 关联Supabase用户
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_config_is_active ON "leak_detection".mnf_baseline_config(is_active);

-- 授权
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "leak_detection".mnf_baseline_config TO anon;

-- 创建触发器函数：自动更新updated_at字段
CREATE OR REPLACE FUNCTION update_mnf_baseline_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER trigger_mnf_baseline_config_updated_at
    BEFORE UPDATE ON "leak_detection".mnf_baseline_config
    FOR EACH ROW
    EXECUTE FUNCTION update_mnf_baseline_config_updated_at();

-- ========================================
-- 区域和基准配置关联表
-- ========================================

-- 区域和基准配置关联表
-- 实现一个基准配置可以应用到多个区域
CREATE TABLE IF NOT EXISTS "leak_detection".mnf_baseline_district_config (
    -- 主键：UUID类型（Supabase推荐）
    id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 关联字段
    config_id            UUID NOT NULL REFERENCES "leak_detection".mnf_baseline_config(id) ON DELETE CASCADE,
    district_id          BIGINT NOT NULL REFERENCES "leak_detection".district(id) ON DELETE CASCADE,
    
    -- 优先级（用于同一区域有多个配置时的优先级排序）
    priority             INTEGER DEFAULT 1 NOT NULL,
    
    -- 状态控制
    is_active            BOOLEAN DEFAULT TRUE,           -- 是否激活
    
    -- 备注信息
    comments             TEXT,                           -- 备注信息
    
    -- Supabase标准时间戳字段
    created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by           UUID REFERENCES auth.users(id),  -- 关联Supabase用户
    
    -- 唯一约束：确保同一区域不会重复关联同一配置
    UNIQUE(config_id, district_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_config_config_id ON "leak_detection".mnf_baseline_district_config(config_id);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_config_district_id ON "leak_detection".mnf_baseline_district_config(district_id);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_config_is_active ON "leak_detection".mnf_baseline_district_config(is_active);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_config_priority ON "leak_detection".mnf_baseline_district_config(priority);

-- 授权
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "leak_detection".mnf_baseline_district_config TO anon;

-- 创建触发器函数：自动更新updated_at字段
CREATE OR REPLACE FUNCTION update_mnf_baseline_district_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER trigger_mnf_baseline_district_config_updated_at
    BEFORE UPDATE ON "leak_detection".mnf_baseline_district_config
    FOR EACH ROW
    EXECUTE FUNCTION update_mnf_baseline_district_config_updated_at(); 