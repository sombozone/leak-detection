-- 插入近三月模拟数据（2024年1月-3月）
-- 注意：父级数据 = 子级数据加总，确保数据一致性

-- 2024年1月数据
INSERT INTO leak_detection.fact_water_balance (
    stat_date, dim_id, 
    water_volume, water_amount, 
    is_estimated, data_source
) VALUES
-- 叶子节点数据（最底层）
-- 收费合法用水量的子分类
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费计量用水量'), 
 65000.000, 39000.000, FALSE, '计费系统'),
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费未计量用水量'), 
 5000.000, 3000.000, FALSE, '计费系统'),

-- 未收费合法用水量的子分类
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费已计量用水量'), 
 3000.000, 1800.000, FALSE, '市政部门'),
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费未计量用水量'), 
 2000.000, 1200.000, FALSE, '消防部门'),

-- 表观漏损的子分类
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '非法用水量'), 
 8000.000, 4800.000, FALSE, '稽查部门'),
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户计量误差和数据处理错误造成的损失水量'), 
 7000.000, 4200.000, FALSE, '计量部门'),

-- 真实漏损的子分类
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '输配水干管漏失水量'), 
 6000.000, 3600.000, FALSE, '漏损检测系统'),
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '蓄水池漏失和溢流水量'), 
 2000.000, 1200.000, FALSE, '漏损检测系统'),
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户支管至计量表具之间漏失水量'), 
 2000.000, 1200.000, FALSE, '漏损检测系统'),

-- 中间节点数据（父级 = 子级加总）
-- 收费合法用水量 = 收费计量用水量 + 收费未计量用水量 = 65000 + 5000 = 70000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费合法用水量'), 
 70000.000, 42000.000, FALSE, '计费系统'),

-- 未收费合法用水量 = 未收费已计量用水量 + 未收费未计量用水量 = 3000 + 2000 = 5000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费合法用水量'), 
 5000.000, 3000.000, FALSE, '市政部门'),

-- 表观漏损 = 非法用水量 + 用户计量误差 = 8000 + 7000 = 15000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '表观漏损'), 
 15000.000, 9000.000, FALSE, '计算得出'),

-- 真实漏损 = 输配水干管漏失 + 蓄水池漏失 + 用户支管漏失 = 6000 + 2000 + 2000 = 10000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), 
 10000.000, 6000.000, FALSE, '漏损检测系统'),

-- 顶层节点数据（父级 = 子级加总）
-- 合法用水量 = 收费合法用水量 + 未收费合法用水量 = 70000 + 5000 = 75000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '合法用水量'), 
 75000.000, 45000.000, FALSE, '计费系统'),

-- 漏损水量 = 表观漏损 + 真实漏损 = 15000 + 10000 = 25000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '漏损水量'), 
 25000.000, 15000.000, FALSE, '计算得出'),

-- 系统供给水量 = 合法用水量 + 漏损水量 = 75000 + 25000 = 100000
('2024-01-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '系统供给水量'), 
 100000.000, 60000.000, FALSE, 'SCADA系统');

-- 2024年2月数据
INSERT INTO leak_detection.fact_water_balance (
    stat_date, dim_id, 
    water_volume, water_amount, 
    is_estimated, data_source
) VALUES
-- 叶子节点数据
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费计量用水量'), 
 68000.000, 40800.000, FALSE, '计费系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费未计量用水量'), 
 5200.000, 3120.000, FALSE, '计费系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费已计量用水量'), 
 3200.000, 1920.000, FALSE, '市政部门'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费未计量用水量'), 
 1800.000, 1080.000, FALSE, '消防部门'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '非法用水量'), 
 7500.000, 4500.000, FALSE, '稽查部门'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户计量误差和数据处理错误造成的损失水量'), 
 6500.000, 3900.000, FALSE, '计量部门'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '输配水干管漏失水量'), 
 5800.000, 3480.000, FALSE, '漏损检测系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '蓄水池漏失和溢流水量'), 
 1900.000, 1140.000, FALSE, '漏损检测系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户支管至计量表具之间漏失水量'), 
 1800.000, 1080.000, FALSE, '漏损检测系统'),

-- 中间节点数据
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费合法用水量'), 
 73200.000, 43920.000, FALSE, '计费系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费合法用水量'), 
 5000.000, 3000.000, FALSE, '市政部门'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '表观漏损'), 
 14000.000, 8400.000, FALSE, '计算得出'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), 
 9500.000, 5700.000, FALSE, '漏损检测系统'),

-- 顶层节点数据
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '合法用水量'), 
 78200.000, 46920.000, FALSE, '计费系统'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '漏损水量'), 
 23500.000, 14100.000, FALSE, '计算得出'),
('2024-02-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '系统供给水量'), 
 101700.000, 61020.000, FALSE, 'SCADA系统');

-- 2024年3月数据
INSERT INTO leak_detection.fact_water_balance (
    stat_date, dim_id, 
    water_volume, water_amount, 
    is_estimated, data_source
) VALUES
-- 叶子节点数据
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费计量用水量'), 
 72000.000, 43200.000, FALSE, '计费系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费未计量用水量'), 
 5500.000, 3300.000, FALSE, '计费系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费已计量用水量'), 
 3500.000, 2100.000, FALSE, '市政部门'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费未计量用水量'), 
 1500.000, 900.000, FALSE, '消防部门'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '非法用水量'), 
 7000.000, 4200.000, FALSE, '稽查部门'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户计量误差和数据处理错误造成的损失水量'), 
 6000.000, 3600.000, FALSE, '计量部门'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '输配水干管漏失水量'), 
 5500.000, 3300.000, FALSE, '漏损检测系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '蓄水池漏失和溢流水量'), 
 1800.000, 1080.000, FALSE, '漏损检测系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '用户支管至计量表具之间漏失水量'), 
 1700.000, 1020.000, FALSE, '漏损检测系统'),

-- 中间节点数据
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '收费合法用水量'), 
 77500.000, 46500.000, FALSE, '计费系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '未收费合法用水量'), 
 5000.000, 3000.000, FALSE, '市政部门'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '表观漏损'), 
 13000.000, 7800.000, FALSE, '计算得出'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '真实漏损'), 
 9000.000, 5400.000, FALSE, '漏损检测系统'),

-- 顶层节点数据
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '合法用水量'), 
 82500.000, 49500.000, FALSE, '计费系统'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '漏损水量'), 
 22000.000, 13200.000, FALSE, '计算得出'),
('2024-03-01', (SELECT id FROM leak_detection.dim_water_balance WHERE name = '系统供给水量'), 
 104500.000, 62700.000, FALSE, 'SCADA系统');