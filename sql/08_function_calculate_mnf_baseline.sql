-- 基于配置的最小流量基准计算函数

-- 获取配置的函数
CREATE OR REPLACE FUNCTION "leak_detection".get_baseline_config(
    p_district_id BIGINT DEFAULT NULL
)
RETURNS TABLE(
    id UUID,
    config_name TEXT,
    calculation_period INTEGER,
    tolerance_percentage DECIMAL(5,2),
    calculation_method TEXT
) AS $$
BEGIN
    -- 如果指定了分区ID，首先尝试获取分区特定配置
    IF p_district_id IS NOT NULL THEN
        RETURN QUERY
        SELECT 
            c.id,
            c.config_name,
            c.calculation_period,
            c.tolerance_percentage,
            c.calculation_method
        FROM "leak_detection".mnf_baseline_config c
        JOIN "leak_detection".mnf_baseline_district_config dc ON c.id = dc.config_id
        WHERE dc.district_id = p_district_id
          AND dc.is_active = TRUE
          AND c.is_active = TRUE
        ORDER BY dc.priority, c.created_at
        LIMIT 1;
        
        -- 如果找到分区配置，返回
        IF FOUND THEN
            RETURN;
        END IF;
    END IF;
    
    -- 如果没有分区配置，返回第一个激活的默认配置
    RETURN QUERY
    SELECT 
        c.id,
        c.config_name,
        c.calculation_period,
        c.tolerance_percentage,
        c.calculation_method
    FROM "leak_detection".mnf_baseline_config c
    WHERE c.is_active = TRUE
      AND NOT EXISTS (
          SELECT 1 FROM "leak_detection".mnf_baseline_district_config dc 
          WHERE dc.config_id = c.id
      )
    ORDER BY c.created_at
    LIMIT 1;
    
    -- 如果没有配置，抛出异常
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active baseline configuration found for district %', p_district_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 计算基准值的函数
CREATE OR REPLACE FUNCTION "leak_detection".calculate_baseline_value(
    p_district_id BIGINT,
    p_start_date DATE,
    p_end_date DATE,
    p_calculation_method TEXT
)
RETURNS DECIMAL(10,3) AS $$
DECLARE
    v_baseline_value DECIMAL(10,3);
BEGIN
    CASE p_calculation_method
        WHEN 'MIN_OF_MIN' THEN
            -- 取最小值
            SELECT MIN(mnf_cumulative_value) INTO v_baseline_value
            FROM "leak_detection".mnf_daily_record
            WHERE district_id = p_district_id
              AND record_date BETWEEN p_start_date AND p_end_date;
              
        WHEN 'AVERAGE' THEN
            -- 取平均值
            SELECT AVG(mnf_cumulative_value) INTO v_baseline_value
            FROM "leak_detection".mnf_daily_record
            WHERE district_id = p_district_id
              AND record_date BETWEEN p_start_date AND p_end_date;
              
        WHEN 'PERCENTILE_25' THEN
            -- 取25%分位数
            SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY mnf_cumulative_value) INTO v_baseline_value
            FROM "leak_detection".mnf_daily_record
            WHERE district_id = p_district_id
              AND record_date BETWEEN p_start_date AND p_end_date;
              
        WHEN 'PERCENTILE_10' THEN
            -- 取10%分位数
            SELECT percentile_cont(0.10) WITHIN GROUP (ORDER BY mnf_cumulative_value) INTO v_baseline_value
            FROM "leak_detection".mnf_daily_record
            WHERE district_id = p_district_id
              AND record_date BETWEEN p_start_date AND p_end_date;
              
        ELSE
            RAISE EXCEPTION 'Unknown calculation method: %', p_calculation_method;
    END CASE;
    
    RETURN v_baseline_value;
END;
$$ LANGUAGE plpgsql;

-- 主计算函数
CREATE OR REPLACE FUNCTION "leak_detection".calculate_mnf_baseline(
    p_district_id BIGINT,
    p_baseline_date DATE DEFAULT CURRENT_DATE,
    p_config_id UUID DEFAULT NULL
)
RETURNS TABLE(
    district_id BIGINT,
    district_name TEXT,
    baseline_date DATE,
    config_id UUID,
    config_name TEXT,
    calculation_period INTEGER,
    calculation_method TEXT,
    tolerance_percentage DECIMAL(5,2),
    start_date DATE,
    end_date DATE,
    data_count INTEGER,
    baseline_mnf_value DECIMAL(10,3),
    baseline_mnf_ratio DECIMAL(5,2),
    min_mnf_value DECIMAL(10,3),
    max_mnf_value DECIMAL(10,3),
    avg_mnf_value DECIMAL(10,3),
    std_dev_mnf_value DECIMAL(10,3),
    data_quality_flag TEXT,
    comments TEXT
) AS $$
DECLARE
    v_id UUID;
    v_config_name TEXT;
    v_calculation_period INTEGER;
    v_tolerance_percentage DECIMAL(5,2);
    v_calculation_method TEXT;
    v_district_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_data_count INTEGER;
    v_baseline_mnf_value DECIMAL(10,3);
    v_baseline_mnf_ratio DECIMAL(5,2);
    v_min_mnf_value DECIMAL(10,3);
    v_max_mnf_value DECIMAL(10,3);
    v_avg_mnf_value DECIMAL(10,3);
    v_std_dev_mnf_value DECIMAL(10,3);
    v_data_quality_flag TEXT;
    v_comments TEXT;
BEGIN
    -- 获取配置
    IF p_config_id IS NOT NULL THEN
        SELECT id, config_name, calculation_period, tolerance_percentage, calculation_method
          INTO v_id, v_config_name, v_calculation_period, v_tolerance_percentage, v_calculation_method
          FROM "leak_detection".mnf_baseline_config
          WHERE id = p_config_id AND is_active = TRUE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Configuration with ID % not found or not active', p_config_id;
        END IF;
    ELSE
        SELECT id, config_name, calculation_period, tolerance_percentage, calculation_method
          INTO v_id, v_config_name, v_calculation_period, v_tolerance_percentage, v_calculation_method
          FROM "leak_detection".get_baseline_config(p_district_id);
    END IF;
    
    -- 获取分区名称
    SELECT name INTO v_district_name 
    FROM "leak_detection".district 
    WHERE id = p_district_id;
    
    IF v_district_name IS NULL THEN
        RAISE EXCEPTION 'District with ID % not found', p_district_id;
    END IF;
    
    -- 计算计算期间
    v_start_date := p_baseline_date - v_calculation_period;
    v_end_date := p_baseline_date - 1;
    
    -- 计算统计数据
    WITH mnf_stats AS (
        SELECT 
            COUNT(*) as data_count,
            MIN(mnf_cumulative_value) as min_mnf_value,
            MAX(mnf_cumulative_value) as max_mnf_value,
            AVG(mnf_cumulative_value) as avg_mnf_value,
            STDDEV(mnf_cumulative_value) as std_dev_mnf_value,
            AVG(mnf_ratio) as avg_mnf_ratio
        FROM "leak_detection".mnf_daily_record mdr
        WHERE mdr.district_id = p_district_id
          AND mdr.record_date BETWEEN v_start_date AND v_end_date
    )
    SELECT 
        ms.data_count,
        ms.min_mnf_value,
        ms.max_mnf_value,
        ms.avg_mnf_value,
        ms.std_dev_mnf_value,
        ms.avg_mnf_ratio
    INTO 
        v_data_count,
        v_min_mnf_value,
        v_max_mnf_value,
        v_avg_mnf_value,
        v_std_dev_mnf_value,
        v_baseline_mnf_ratio
    FROM mnf_stats ms;
    
    -- 计算基准值
    v_baseline_mnf_value := "leak_detection".calculate_baseline_value(
        p_district_id, 
        v_start_date, 
        v_end_date, 
        v_calculation_method
    );
    
    -- 判断数据质量（简化版本）
    IF v_data_count = 0 THEN
        v_data_quality_flag := 'BAD';
        v_comments := '无数据';
    ELSIF v_data_count < v_calculation_period * 0.5 THEN
        v_data_quality_flag := 'BAD';
        v_comments := '数据严重不足，实际数据条数: ' || v_data_count || '，期望: ' || v_calculation_period;
    ELSIF v_data_count < v_calculation_period * 0.8 THEN
        v_data_quality_flag := 'WARNING';
        v_comments := '数据不足，实际数据条数: ' || v_data_count || '，期望: ' || v_calculation_period;
    ELSE
        v_data_quality_flag := 'GOOD';
        v_comments := '数据充足，基于前' || v_calculation_period || '天数据计算';
    END IF;
    
    -- 返回结果
    RETURN QUERY SELECT 
        p_district_id,
        v_district_name,
        p_baseline_date,
        v_id,
        v_config_name,
        v_calculation_period,
        v_calculation_method,
        v_tolerance_percentage,
        v_start_date,
        v_end_date,
        v_data_count,
        v_baseline_mnf_value,
        v_baseline_mnf_ratio,
        v_min_mnf_value,
        v_max_mnf_value,
        v_avg_mnf_value,
        v_std_dev_mnf_value,
        v_data_quality_flag,
        v_comments;
END;
$$ LANGUAGE plpgsql;

-- 插入或更新基准数据的函数
CREATE OR REPLACE FUNCTION "leak_detection".upsert_mnf_baseline(
    p_district_id BIGINT,
    p_baseline_date DATE DEFAULT CURRENT_DATE,
    p_config_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_baseline_id UUID;
    v_result RECORD;
BEGIN
    -- 调用计算函数获取基准数据
    SELECT * INTO v_result
    FROM "leak_detection".calculate_mnf_baseline(p_district_id, p_baseline_date, p_config_id);
    
    -- 检查是否已存在基准记录
    SELECT id INTO v_baseline_id
    FROM "leak_detection".mnf_baseline
    WHERE district_id = p_district_id 
      AND baseline_date = p_baseline_date
      AND config_id = v_result.config_id
      AND is_active = TRUE;
    
    IF v_baseline_id IS NOT NULL THEN
        -- 更新现有记录
        UPDATE "leak_detection".mnf_baseline
        SET 
            calculation_period = v_result.calculation_period,
            calculation_method = v_result.calculation_method,
            tolerance_percentage = v_result.tolerance_percentage,
            start_date = v_result.start_date,
            end_date = v_result.end_date,
            data_count = v_result.data_count,
            baseline_mnf_value = v_result.baseline_mnf_value,
            baseline_mnf_ratio = v_result.baseline_mnf_ratio,
            min_mnf_value = v_result.min_mnf_value,
            max_mnf_value = v_result.max_mnf_value,
            avg_mnf_value = v_result.avg_mnf_value,
            std_dev_mnf_value = v_result.std_dev_mnf_value,
            data_quality_flag = v_result.data_quality_flag,
            comments = v_result.comments,
            updated_at = NOW()
        WHERE id = v_baseline_id;
    ELSE
        -- 插入新记录
        INSERT INTO "leak_detection".mnf_baseline (
            district_id, district_name, baseline_date, config_id,
            calculation_period, calculation_method, tolerance_percentage,
            start_date, end_date, data_count, baseline_mnf_value, baseline_mnf_ratio,
            min_mnf_value, max_mnf_value, avg_mnf_value, std_dev_mnf_value,
            data_quality_flag, comments
        ) VALUES (
            v_result.district_id, v_result.district_name, v_result.baseline_date, v_result.config_id,
            v_result.calculation_period, v_result.calculation_method, v_result.tolerance_percentage,
            v_result.start_date, v_result.end_date, v_result.data_count, v_result.baseline_mnf_value, v_result.baseline_mnf_ratio,
            v_result.min_mnf_value, v_result.max_mnf_value, v_result.avg_mnf_value, v_result.std_dev_mnf_value,
            v_result.data_quality_flag, v_result.comments
        ) RETURNING id INTO v_baseline_id;
    END IF;
    
    RETURN v_baseline_id;
END;
$$ LANGUAGE plpgsql;

-- 批量计算所有分区的基准数据
CREATE OR REPLACE FUNCTION "leak_detection".calculate_all_districts_baseline(
    p_baseline_date DATE DEFAULT CURRENT_DATE,
    p_config_id UUID DEFAULT NULL
)
RETURNS TABLE(
    district_id BIGINT,
    district_name TEXT,
    baseline_id UUID,
    status TEXT
) AS $$
DECLARE
    v_district RECORD;
    v_baseline_id UUID;
    v_status TEXT;
BEGIN
    -- 遍历所有分区
    FOR v_district IN 
        SELECT id, name 
        FROM "leak_detection".district 
        WHERE is_active = TRUE
    LOOP
        BEGIN
            -- 计算基准数据
            v_baseline_id := "leak_detection".upsert_mnf_baseline(
                v_district.id, 
                p_baseline_date, 
                p_config_id
            );
            v_status := 'SUCCESS';
        EXCEPTION WHEN OTHERS THEN
            v_baseline_id := NULL;
            v_status := 'ERROR: ' || SQLERRM;
        END;
        
        -- 返回结果
        district_id := v_district.id;
        district_name := v_district.name;
        baseline_id := v_baseline_id;
        status := v_status;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql; 