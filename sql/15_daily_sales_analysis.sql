-- 创建产销查分析日报表 编号 15
CREATE TABLE daily_sales_analysis (
    record_date DATE NOT NULL,
    district_name TEXT NOT NULL,                  -- 分区名称
    district_id INT NOT NULL,
    district_pid INT NOT NULL,
    water_supply DECIMAL(20, 2) NOT NULL,
    residential_sales DECIMAL(20, 2) NOT NULL,
    large_user_sales DECIMAL(20, 2) NOT NULL,
    total_sales DECIMAL(20, 2) NOT NULL,
    total_users INT NOT NULL,                     -- 用户总数
    read_users INT NOT NULL,                      -- 已抄表用户数
    unread_users INT NOT NULL,                    -- 未抄件用户数
    sales_difference DECIMAL(20, 2) GENERATED ALWAYS AS (
        CASE 
            WHEN water_supply IS NOT NULL AND total_sales IS NOT NULL THEN 
                water_supply - total_sales
            ELSE NULL 
        END
    ) STORED,  -- 产销差
    sales_difference_rate DECIMAL(5, 2) GENERATED ALWAYS AS (
        CASE 
            WHEN water_supply IS NOT NULL AND water_supply > 0 THEN 
                ROUND(((water_supply - total_sales) / water_supply) * 100, 2)
            ELSE NULL 
        END
    ) STORED,  -- 产销差率
    PRIMARY KEY (record_date, district_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE leak_detection.daily_sales_analysis TO anon; 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE leak_detection.daily_sales_analysis TO authenticated; 