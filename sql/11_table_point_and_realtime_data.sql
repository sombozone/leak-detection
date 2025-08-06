-- 点位基础信息表
CREATE TABLE IF NOT EXISTS leak_detection.point_tag (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY, -- 唯一编码
    code        TEXT NOT NULL,                              -- 点位编号
    src         TEXT NOT NULL,                              -- 数据源标识
    description TEXT,                                       -- 点位描述（可选）
    UNIQUE(code, src)                                       -- 同一数据源下code唯一
);

-- 可选索引
CREATE INDEX IF NOT EXISTS idx_point_tag_code ON leak_detection.point_tag(code);
CREATE INDEX IF NOT EXISTS idx_point_tag_src ON leak_detection.point_tag(src);

-- 实时点位数据超表（TimescaleDB hypertable）
CREATE TABLE IF NOT EXISTS leak_detection.rt_point_data (
    recorded_time   TIMESTAMPTZ NOT NULL,                      -- 记录到服务器的时间
    point_id        UUID NOT NULL REFERENCES leak_detection.point_tag(id), -- 点位唯一编码
    val             NUMERIC NOT NULL,                          -- 点位实时值
    quality         INT4 DEFAULT 192 NOT NULL,                 -- 数据质量
    source_time     TIMESTAMPTZ NULL                           -- 点位来源的更新时间
);

-- 将表转换为TimescaleDB超表
SELECT create_hypertable('leak_detection.rt_point_data', 'recorded_time', if_not_exists => TRUE);

-- 可选索引
CREATE INDEX IF NOT EXISTS idx_rt_point_data_point_time ON leak_detection.rt_point_data(point_id, recorded_time DESC); 