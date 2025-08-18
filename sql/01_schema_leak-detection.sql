CREATE SCHEMA IF NOT EXISTS "leak_detection"; 

-- 创建外部服务器
CREATE SERVER mysql_server
  FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host '10.38.245.88', port '3309');

-- 创建用户映射 - 为多个用户创建映射
-- CREATE USER MAPPING FOR current_user
--   SERVER mysql_server
--   OPTIONS (username 'root', password '123@abc.com');

-- 为anon用户创建映射（解决"user mapping not found for user anon"错误）
CREATE USER MAPPING FOR anon
  SERVER mysql_server
  OPTIONS (username 'root', password '123@abc.com');

-- 为authenticated用户创建映射
CREATE USER MAPPING FOR authenticated
  SERVER mysql_server
  OPTIONS (username 'root', password '123@abc.com');

-- 为service_role用户创建映射（如果使用Supabase）
CREATE USER MAPPING FOR service_role
  SERVER mysql_server
  OPTIONS (username 'root', password '123@abc.com');

-- 创建外部表：漏损分区管理表
CREATE FOREIGN TABLE leakage_partition_management (
  id bigint,
  partition_name varchar(255),
  partition_range text,
  partition_center varchar(100),
  partition_color varchar(50),
  sort int,
  "area" float,
  pipeline_length float,
  user_count int,
  average_pressure float,
  administrator varchar(255),
  phone varchar(20),
  connected_users int,
  unconnected_users int,
  meter_reading_cycle int,
  affiliated_organization_id int,
  is_community boolean,
  is_remote_transmission_community boolean,
  is_secondary_supply_community boolean,
  create_time timestamp,
  create_by varchar(255),
  update_time timestamp,
  update_by varchar(255),
  del_flag char(1),
  partition_code varchar(50),
  pid bigint,
  partition_type varchar(255),
  is_last_node int,
  pic_url text
)
SERVER mysql_server
OPTIONS (dbname 'sc_leakage', table_name 'leakage_partition_management');

