-- 水平衡维度基础表
-- 用于管理水平衡的供水量、用水量、漏损量的统计口径
-- 支持双分类体系：主分类(pid_0)和辅助分类(pid_1)
CREATE TABLE IF NOT EXISTS leak_detection.dim_water_balance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY, -- 维度ID (UUID)
    name VARCHAR(100) NOT NULL, -- 维度名称
    pid UUID REFERENCES leak_detection.dim_water_balance(id) ON DELETE CASCADE, 
    group_name VARCHAR(100), -- 分组名称
    sort_num INTEGER DEFAULT 0, -- 排序
    is_active BOOLEAN DEFAULT TRUE, -- 是否启用
    description TEXT, -- 描述
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_pid ON leak_detection.dim_water_balance(pid);

-- 创建触发器函数：自动更新updated_at字段
CREATE OR REPLACE FUNCTION update_dim_water_balance_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建触发器
CREATE TRIGGER trigger_dim_water_balance_updated_at
    BEFORE UPDATE ON leak_detection.dim_water_balance
    FOR EACH ROW
    EXECUTE FUNCTION update_dim_water_balance_updated_at();

-- 插入基础数据
INSERT INTO leak_detection.dim_water_balance (name, pid, group_name, sort_num, description) VALUES
-- 顶层维度
('系统供给水量', NULL, '默认分组', 1, '系统总供水量'),
-- 主分类：用途分类
('合法用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '系统供给水量'), '默认分组', 2, '合法用水总量'),
('漏损水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '系统供给水量'), '默认分组', 3, '漏损水总量'),
-- 合法用水量的子维度
('收费合法用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '合法用水量'), '默认分组', 6, '收费的合法用水量'),
('未收费合法用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '合法用水量'), '默认分组', 7, '未收费的合法用水量'),
-- 漏损水量的子维度
('表观漏损', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '漏损水量'), '默认分组', 8, '表观漏损水量'),
('真实漏损', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '漏损水量'), '默认分组', 9, '真实漏损水量'),
-- 插入收费合法用水量的子分类
('收费计量用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费合法用水量'), '默认分组', 10, '居民、工业、商业等计量用水量'),
('收费未计量用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费合法用水量'), '默认分组', 11, '临时用水估收水费、估水量抵押物品'),
-- 插入未收费合法用水量的子分类
('未收费已计量用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费合法用水量'), '默认分组', 12, '市政用水、绿化用水'),
('未收费未计量用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费合法用水量'), '默认分组', 13, '消防用水'),
-- 插入表观漏损的子分类
('非法用水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '表观漏损'), '默认分组', 14, '偷水、滴水、漏水'),
('用户计量误差和数据处理错误造成的损失水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '表观漏损'), '默认分组', 15, '表具计量误差、少抄、漏抄、估抄、人情抄'),
-- 插入真实漏损的子分类
('输配水干管漏失水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), '默认分组', 16, '输配水干管漏失水量'),
('蓄水池漏失和溢流水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), '默认分组', 17, '蓄水池漏失和溢流水量'),
('用户支管至计量表具之间漏失水量', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), '默认分组', 18, '用户支管至计量表具之间漏失水量');

-- 授权
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE leak_detection.dim_water_balance TO anon; 