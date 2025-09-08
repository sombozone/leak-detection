# 基于配置的最小流量基准系统

## 系统概述

基于配置的最小流量基准系统是一个灵活、可配置的基准计算系统，用于基于历史夜间最小流量数据建立基准值。系统支持多种计算方法、可配置的参数，并能够为不同区域设置不同的配置策略。

## 系统架构

### 核心组件

1. **配置表** (`mnf_baseline_config`) - 管理基准计算的配置参数
2. **区域配置关联表** (`mnf_baseline_district_config`) - 管理区域和配置的关联关系
3. **基准表** (`mnf_baseline`) - 存储计算出的基准数据
4. **计算函数** - 基于配置执行基准计算
5. **视图** - 提供便捷的查询接口

### 设计理念

- **配置驱动**：所有计算参数通过配置表管理
- **区域定制**：支持为不同区域设置不同的配置策略
- **方法多样**：支持多种基准计算方法
- **数据完整性**：使用所有可用数据进行计算，不进行数据质量过滤
- **优先级管理**：支持同一区域多个配置的优先级排序

## 表结构

### mnf_baseline_config 配置表

```sql
-- 核心配置字段
calculation_period   INTEGER DEFAULT 10,     -- 计算周期（天数）
tolerance_percentage DECIMAL(5,2) DEFAULT 10.00, -- 容差百分比
calculation_method   TEXT DEFAULT 'MIN_OF_MIN', -- 计算方法

-- 状态控制
is_active            BOOLEAN DEFAULT TRUE,   -- 是否激活
```

### mnf_baseline_district_config 区域配置关联表

```sql
-- 关联字段
config_id            UUID REFERENCES mnf_baseline_config(id), -- 配置ID
district_id          BIGINT REFERENCES district(id),         -- 区域ID
priority             INTEGER DEFAULT 1,                      -- 优先级
is_active            BOOLEAN DEFAULT TRUE,                   -- 是否激活

-- 唯一约束
UNIQUE(config_id, district_id)                               -- 防止重复关联
```

### mnf_baseline 基准表

```sql
-- 基准数据
baseline_mnf_value   DECIMAL(10,3),          -- 基准最小流量值
baseline_mnf_ratio   DECIMAL(5,2),           -- 基准最小流量占比

-- 统计信息
min_mnf_value, max_mnf_value, avg_mnf_value, std_dev_mnf_value

-- 自动计算的阈值
upper_threshold, lower_threshold             -- 上下限阈值
```

## 计算方法

系统支持以下计算方法：

1. **MIN_OF_MIN** - 最小值的最小值（默认）
2. **AVERAGE** - 平均值
3. **PERCENTILE_25** - 25%分位数
4. **PERCENTILE_10** - 10%分位数

## 配置策略

### 配置优先级

1. **区域特定配置** - 通过关联表为特定区域设置的配置（按优先级排序）
2. **默认配置** - 未关联到任何区域的全局配置

### 配置示例

```sql
-- 创建配置
INSERT INTO mnf_baseline_config (
    config_name, calculation_period, tolerance_percentage, 
    calculation_method, is_active
) VALUES (
    'SENSITIVE_CONFIG', 7, 8.00, 'MIN_OF_MIN', TRUE
);

-- 为区域分配配置
INSERT INTO mnf_baseline_district_config (
    config_id, district_id, priority, is_active
) VALUES (
    config_id, 1, 1, TRUE
);
```

## 核心函数

### 1. 配置获取函数

```sql
-- 获取指定区域的配置
SELECT * FROM "leak_detection".get_baseline_config(p_district_id);

-- 获取默认配置
SELECT * FROM "leak_detection".get_baseline_config();
```

### 2. 基准计算函数

```sql
-- 计算基准数据（使用区域配置）
SELECT * FROM "leak_detection".calculate_mnf_baseline(
    p_district_id, p_baseline_date
);

-- 计算基准数据（使用特定配置覆盖）
SELECT * FROM "leak_detection".calculate_mnf_baseline(
    p_district_id, p_baseline_date, p_config_id
);
```

### 3. 数据插入/更新函数

```sql
-- 插入或更新基准数据
SELECT "leak_detection".upsert_mnf_baseline(
    p_district_id, p_baseline_date, p_config_id
);
```

### 4. 批量计算函数

```sql
-- 为所有区域批量计算基准数据
SELECT * FROM "leak_detection".calculate_all_districts_baseline(
    p_baseline_date, p_config_id
);
```

## 使用方法

### 步骤1：创建表结构和函数

执行以下SQL文件：
- `06_table_mnf_baseline_config.sql` - 创建配置表和关联表
- `07_table_mnf_baseline.sql` - 创建基准表
- `08_function_calculate_mnf_baseline.sql` - 创建计算函数

### 步骤2：插入配置数据

```sql
-- 执行配置数据
\i sql/09_data_mnf_baseline_config.sql
```

### 步骤3：计算基准数据

```sql
-- 为所有区域计算基准数据
SELECT * FROM "leak_detection".calculate_all_districts_baseline('2024-01-08');
```

### 步骤4：查看结果

```sql
-- 查看基准数据汇总
SELECT * FROM "leak_detection".v_mnf_baseline_summary;

-- 查看基准数据与日常数据对比
SELECT * FROM "leak_detection".v_mnf_daily_vs_baseline;
```

## 视图说明

### v_mnf_baseline_summary
基准数据汇总视图，显示各区域的基准值、配置信息等。

### v_mnf_daily_vs_baseline
基准数据与日常数据对比视图，用于异常检测：
- `threshold_status`：阈值状态
- `deviation_percentage`：偏离基准的百分比

## 配置管理

### 添加新配置

```sql
INSERT INTO "leak_detection".mnf_baseline_config (
    config_name, config_description,
    calculation_period, tolerance_percentage, calculation_method
) VALUES (
    'NEW_CONFIG', '新配置描述',
    10, 10.00, 'MIN_OF_MIN'
);
```

### 为区域分配配置

```sql
-- 为区域分配配置
INSERT INTO "leak_detection".mnf_baseline_district_config (
    config_id, district_id, priority, is_active, comments
) VALUES (
    config_id, district_id, 1, TRUE, '区域配置描述'
);
```

### 修改配置

```sql
UPDATE "leak_detection".mnf_baseline_config
SET calculation_period = 14, tolerance_percentage = 12.00
WHERE config_name = 'CONFIG_NAME';
```

### 配置切换

```sql
-- 停用当前配置
UPDATE "leak_detection".mnf_baseline_config
SET is_active = FALSE
WHERE is_active = TRUE;

-- 激活新配置
UPDATE "leak_detection".mnf_baseline_config
SET is_active = TRUE
WHERE config_name = 'NEW_CONFIG';
```

## 区域配置管理

### 查看区域配置分配

```sql
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
```

### 修改区域配置优先级

```sql
UPDATE "leak_detection".mnf_baseline_district_config
SET priority = 2, comments = '优先级调整'
WHERE district_id = 1 AND config_id = config_id;
```

### 为新区分配配置

```sql
INSERT INTO "leak_detection".mnf_baseline_district_config (
    config_id, district_id, priority, is_active, comments
) VALUES (
    config_id, new_district_id, 1, TRUE, '新区配置'
);
```

## 数据质量评估

系统根据以下标准评估数据质量（基于数据完整性）：

- **GOOD**：数据条数 ≥ 期望条数的80%
- **WARNING**：数据条数在期望条数的50%-80%之间
- **BAD**：数据条数 < 期望条数的50% 或 无数据

**注意**：系统使用所有可用的数据进行基准计算，不进行数据质量过滤。

## 应用场景

1. **漏损检测**：当日最小流量超过基准阈值时触发告警
2. **趋势分析**：跟踪基准值的变化趋势
3. **异常识别**：识别异常的最小流量数据
4. **配置优化**：根据实际效果调整配置参数
5. **区域差异化**：为不同区域设置不同的检测策略

## 维护建议

1. **定期更新**：根据业务需求定期更新基准数据
2. **配置优化**：根据实际效果调整配置参数
3. **数据清理**：定期清理过期的基准数据
4. **监控告警**：监控基准计算的执行状态和数据质量
5. **区域管理**：定期检查和调整区域配置分配

## 示例查询

```sql
-- 查看异常数据
SELECT * FROM "leak_detection".v_mnf_daily_vs_baseline 
WHERE threshold_status != 'NORMAL';

-- 查看不同配置的效果对比
SELECT 
    district_name, config_name, calculation_method,
    baseline_mnf_value, upper_threshold, lower_threshold
FROM "leak_detection".v_mnf_baseline_summary
WHERE baseline_date = '2024-01-08';

-- 查看配置使用情况
SELECT 
    config_name, COUNT(*) as usage_count
FROM "leak_detection".mnf_baseline b
JOIN "leak_detection".mnf_baseline_config c ON b.config_id = c.id
GROUP BY config_name;

-- 查看区域配置分配情况
SELECT 
    d.name as district_name,
    c.config_name,
    dc.priority,
    c.calculation_method
FROM "leak_detection".mnf_baseline_district_config dc
JOIN "leak_detection".mnf_baseline_config c ON dc.config_id = c.id
JOIN "leak_detection".district d ON dc.district_id = d.id
WHERE dc.is_active = TRUE
ORDER BY d.id, dc.priority;
```

## 文件清单

- `06_table_mnf_baseline_config.sql` - 配置表和关联表结构
- `07_table_mnf_baseline.sql` - 基准表结构
- `08_function_calculate_mnf_baseline.sql` - 计算函数
- `09_data_mnf_baseline_config.sql` - 配置和关联示例数据
- `10_demo_mnf_baseline_system.sql` - 系统演示脚本
- `README_mnf_baseline_system.md` - 本文档 