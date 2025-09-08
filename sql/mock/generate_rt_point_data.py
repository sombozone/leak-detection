import random
from datetime import datetime, timedelta

# 实际点位ID与tag对应关系
point_tags = [
    {"tag": "FLOW_A_01", "id": "e8361939-ef98-4929-8804-b2c11f143db1"},
    {"tag": "FLOW_A_02", "id": "5ba2a21d-fa45-4c20-a12b-a002b1da78ce"},
    {"tag": "FLOW_B_01", "id": "35ef1079-acec-4c42-86ea-c36d8d6bfd8a"},
    {"tag": "FLOW_B_02", "id": "0183f747-2423-48b6-a58f-df2dff22ab2b"},
    {"tag": "FLOW_B_03", "id": "674765fd-6109-41d9-8cd7-28bc8fd968af"},
    {"tag": "FLOW_C_01", "id": "42a6cb03-9446-4011-b820-ff671ec0fa86"},
    {"tag": "FLOW_C_02", "id": "9abd04b1-ff79-48cb-a44f-09f88124cd51"},
]

start_date = datetime(2025, 7, 1, 0, 0)
days = 30

def is_peak_hour(hour):
    """判断是否为高峰时段"""
    return (7 <= hour < 9) or (12 <= hour < 14) or (19 <= hour < 22)

def is_low_hour(hour):
    """判断是否为凌晨低谷时段"""
    return 2 <= hour < 5

def get_flow_value(hour):
    """根据时段生成流量值"""
    # 高峰时段：流量较高
    if is_peak_hour(hour):
        return round(random.uniform(80, 120), 2)
    # 低谷时段（2-5点）：流量很低
    elif is_low_hour(hour):
        return round(random.uniform(10, 30), 2)
    # 其他时段：流量中等
    else:
        return round(random.uniform(40, 70), 2)

def generate_time_points():
    """生成需要采集的时间点"""
    time_points = []
    current = start_date
    
    for day in range(days):
        for hour in range(24):
            current_time = current + timedelta(days=day, hours=hour)
            
            if is_peak_hour(hour) or is_low_hour(hour):
                # 高峰时段和凌晨时段：每小时一次
                time_points.append(current_time)
            else:
                # 其他时段：每2小时一次（0点、2点、4点、6点、8点、10点、12点、14点、16点、18点、20点、22点）
                if hour % 2 == 0:
                    time_points.append(current_time)
    
    return time_points

# 生成时间点
time_points = generate_time_points()

# 生成SQL
with open("insert_rt_point_data.sql", "w", encoding="utf-8") as f:
    f.write("-- 插入rt_point_data测试数据\n")
    f.write("-- 高峰时段（7-9点、12-14点、19-22点）：每小时一次\n")
    f.write("-- 凌晨时段（2-5点）：每小时一次\n")
    f.write("-- 其他时段：每2小时一次\n")
    f.write("-- 时间范围：2025-07-01 至 2025-07-30\n\n")
    
    for pt in point_tags:
        f.write(f"-- {pt['tag']} 点位数据\n")
        for time_point in time_points:
            value = get_flow_value(time_point.hour)
            sql = (
                f"INSERT INTO leak_detection.rt_point_data "
                f"(recorded_time, point_id, val, quality, source_time) VALUES "
                f"('{time_point.strftime('%Y-%m-%d %H:%M:%S+08')}', '{pt['id']}', {value}, 192, '{time_point.strftime('%Y-%m-%d %H:%M:%S+08')}');\n"
            )
            f.write(sql)
        f.write("\n")

print(f"SQL文件已生成：insert_rt_point_data.sql")
print(f"时间范围：{start_date.strftime('%Y-%m-%d')} 至 {(start_date + timedelta(days=days-1)).strftime('%Y-%m-%d')}")
print(f"点位数量：{len(point_tags)}")
print(f"每天时间点数量：{len([t for t in time_points if t.date() == start_date.date()])}")
print(f"总数据条数：{len(point_tags) * len(time_points)}") 