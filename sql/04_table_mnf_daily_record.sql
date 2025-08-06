CREATE TABLE IF NOT EXISTS leak_detection.mnf_daily_record (
    -- 主键：UUID类型（Supabase推荐）
    id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- 业务标识字段
    district_id          BIGINT REFERENCES leak_detection.district(id) NOT NULL,  -- 分区ID
    district_name        TEXT NOT NULL,                  -- 分区名称  
    record_date         DATE NOT NULL,                  -- 记录日期
    
    -- 瞬时MNF数据
    mnf_instant_value   DECIMAL(10,3),                  -- 夜间最小流量瞬时值(L/s)
    mnf_instant_time    TIMESTAMPTZ,                    -- 瞬时值采集时间（带时区）
    
    -- 累计MNF数据  
    mnf_cumulative_value DECIMAL(10,3),                 -- 夜间最小流量累计值(L/s)
    mnf_period_start    TIME DEFAULT '02:00:00',        -- 采集时段开始
    mnf_period_end      TIME DEFAULT '04:00:00',        -- 采集时段结束
    
    -- 对比数据
    max_flow_value      DECIMAL(10,3),                  -- 最大流量值(L/s)
    max_flow_period_start TIME,                         -- 最大流量时段开始
    max_flow_period_end   TIME,                         -- 最大流量时段结束
    
    -- 统计数据
    avg_daily_flow      DECIMAL(10,3),                  -- 日平均流量(L/s)
    total_daily_volume  DECIMAL(12,2),                  -- 日累计水量(m³)
    mnf_ratio           DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE 
            WHEN avg_daily_flow > 0 THEN 
                ROUND((mnf_cumulative_value / avg_daily_flow * 100)::DECIMAL(5,2), 2)
            ELSE NULL 
        END
    ) STORED,                                           -- 夜间最小流量占比(%)
    
    -- 质量控制字段
    data_quality_flag   TEXT CHECK (data_quality_flag IN ('GOOD','WARNING','BAD')) DEFAULT 'GOOD',
    anomaly_flag        BOOLEAN DEFAULT FALSE,          -- 异常标记
    comments           TEXT,                            -- 备注信息
    
    -- Supabase标准时间戳字段
    created_at         TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at         TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    created_by         UUID REFERENCES auth.users(id),  -- 关联Supabase用户
    
    -- 唯一约束：分区+日期组合唯一
    CONSTRAINT unique_district_date UNIQUE (district_id, record_date)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_mnf_daily_record_district_id ON leak_detection.mnf_daily_record(district_id);
CREATE INDEX IF NOT EXISTS idx_mnf_daily_record_record_date ON leak_detection.mnf_daily_record(record_date);
CREATE INDEX IF NOT EXISTS idx_mnf_daily_record_district_date ON leak_detection.mnf_daily_record(district_id, record_date);

-- 授权
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE leak_detection.mnf_daily_record TO anon; 