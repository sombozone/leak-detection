CREATE TYPE leak_detection.district_level AS ENUM ('城区', '乡镇', '一级', '二级', '三级', '四级', '五级');

CREATE TABLE IF NOT EXISTS leak_detection.district (
    id BIGSERIAL PRIMARY KEY, -- 分区编号
    name VARCHAR(100) NOT NULL, -- 分区名称
    region TEXT, -- 分区范围（多边形坐标串或GeoJSON）
    center VARCHAR(50), -- 分区中心（经度,纬度 或 GeoJSON点）
    color VARCHAR(20), -- 分区颜色
    sort INTEGER DEFAULT 0, -- 排序
    area DOUBLE PRECISION, -- 面积
    pipe_len DOUBLE PRECISION, -- 管网长度
    user_num INTEGER, -- 挂接用户数
    user_num_unlinked INTEGER, -- 未挂接用户数
    cycle VARCHAR(50), -- 抄表周期
    lvl leak_detection.district_level , -- 分区层级
    mgr VARCHAR(100), -- 分区负责人
    org VARCHAR(100), -- 所属组织
    is_comm BOOLEAN DEFAULT FALSE, -- 是否小区
    is_remote BOOLEAN DEFAULT FALSE, -- 是否远传小区
    is_comm_secondary BOOLEAN DEFAULT FALSE, -- 是否二供小区
    pid BIGINT REFERENCES leak_detection.district(id) ON DELETE SET NULL, -- 上级分区ID（自关联）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_district_area ON leak_detection.district USING GIST (area);
CREATE INDEX IF NOT EXISTS idx_district_center ON leak_detection.district USING GIST (center); 

-- 授权 schema
GRANT USAGE ON SCHEMA leak_detection TO anon;
-- 授权表
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE leak_detection.district TO anon; 

-- 插入城区分区
INSERT INTO leak_detection.district (name, region, center, lvl)
VALUES
('城南', '', '', '城区'),
('城北', '', '', '城区'),
('蒲纺', '', '', '城区');

-- 获取城区分区ID并插入一级分区（假设ID为1、2、3，实际可用RETURNING或查找）
-- 城南下属一级分区
INSERT INTO leak_detection.district (name, region, center, lvl, pid)
VALUES
('城南-一分区', '', '', '一级', 1),
('城南-二分区', '', '', '一级', 1);
-- 城北下属一级分区
INSERT INTO leak_detection.district (name, region, center, lvl, pid)
VALUES
('城北-一分区', '', '', '一级', 2),
('城北-二分区', '', '', '一级', 2);
-- 蒲纺下属一级分区
INSERT INTO leak_detection.district (name, region, center, lvl, pid)
VALUES
('蒲纺-一分区', '', '', '一级', 3),
('蒲纺-二分区', '', '', '一级', 3); 

-- 蒲纺-一分区下属二级分区
INSERT INTO leak_detection.district (name, region, center, lvl, pid)
VALUES
('蒲纺-一分区A', '', '', '二级', (SELECT id FROM leak_detection.district WHERE name = '蒲纺-一分区')),
('蒲纺-一分区B', '', '', '二级', (SELECT id FROM leak_detection.district WHERE name = '蒲纺-一分区')),
('蒲纺-一分区C', '', '', '二级', (SELECT id FROM leak_detection.district WHERE name = '蒲纺-一分区')); 

