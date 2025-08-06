-- 最小流量基准表
-- 专门用于存储基于配置计算的基准数据
CREATE TABLE IF NOT EXISTS "leak_detection".mnf_baseline (
    -- 主键：UUID类型（Supabase推荐）
    id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 业务标识字段
    district_id          BIGINT REFERENCES "leak_detection".district(id) NOT NULL,  -- 分区ID
    district_name        TEXT NOT NULL,                  -- 分区名称  
    baseline_date        DATE NOT NULL,                  -- 基准日期（计算基准的日期）
    config_id            UUID REFERENCES "leak_detection".mnf_baseline_config(id) NOT NULL, -- 配置ID
    
    -- 基准计算参数（从配置表复制，便于查询）
    calculation_period   INTEGER NOT NULL,               -- 计算周期（天数）
    calculation_method   TEXT NOT NULL,                  -- 计算方法
    tolerance_percentage DECIMAL(5,2) NOT NULL,          -- 容差百分比
    
    -- 计算期间
    start_date           DATE NOT NULL,                  -- 计算开始日期
    end_date             DATE NOT NULL,                  -- 计算结束日期
    data_count           INTEGER NOT NULL,               -- 实际参与计算的数据条数
    
    -- 基准值
    baseline_mnf_value   DECIMAL(10,3) NOT NULL,         -- 基准最小流量值(L/s)
    baseline_mnf_ratio   DECIMAL(5,2),                   -- 基准最小流量占比(%)
    
    -- 统计信息
    min_mnf_value        DECIMAL(10,3),                  -- 计算期间最小流量最小值
    max_mnf_value        DECIMAL(10,3),                  -- 计算期间最小流量最大值
    avg_mnf_value        DECIMAL(10,3),                  -- 计算期间最小流量平均值
    std_dev_mnf_value    DECIMAL(10,3),                  -- 计算期间最小流量标准差
    
    -- 阈值（自动计算）
    upper_threshold      DECIMAL(10,3) GENERATED ALWAYS AS (
        baseline_mnf_value * (1 + tolerance_percentage / 100)
    ) STORED,                                            -- 上限阈值
    lower_threshold      DECIMAL(10,3) GENERATED ALWAYS AS (
        baseline_mnf_value * (1 - tolerance_percentage / 100)
    ) STORED,                                            -- 下限阈值
    
    -- 质量控制字段
    data_quality_flag    TEXT CHECK (data_quality_flag IN ('GOOD','WARNING','BAD')) DEFAULT 'GOOD',
    is_active            BOOLEAN DEFAULT TRUE,           -- 是否激活（用于版本控制）
    comments             TEXT,                           -- 备注信息
    
    -- Supabase标准时间戳字段
    created_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at           TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by           UUID REFERENCES auth.users(id) -- 关联Supabase用户
    
    -- 唯一约束：分区+基准日期+配置组合唯一
    CONSTRAINT unique_district_baseline_date_config UNIQUE (district_id, baseline_date, config_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_id ON "leak_detection".mnf_baseline(district_id);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_baseline_date ON "leak_detection".mnf_baseline(baseline_date);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_config_id ON "leak_detection".mnf_baseline(config_id);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_district_date ON "leak_detection".mnf_baseline(district_id, baseline_date);
CREATE INDEX IF NOT EXISTS idx_mnf_baseline_is_active ON "leak_detection".mnf_baseline(is_active);

-- 授权
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "leak_detection".mnf_baseline TO anon;

-- 创建触发器函数：自动更新updated_at字段
CREATE OR REPLACE FUNCTION update_mnf_baseline_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER trigger_mnf_baseline_updated_at
    BEFORE UPDATE ON "leak_detection".mnf_baseline
    FOR EACH ROW
    EXECUTE FUNCTION update_mnf_baseline_updated_at(); 