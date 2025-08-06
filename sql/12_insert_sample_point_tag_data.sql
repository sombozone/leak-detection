-- 插入简化的point_tag数据
-- 每个片区的流量点都是平级的

INSERT INTO leak_detection.point_tag (id, code, src, description) VALUES
('e8361939-ef98-4929-8804-b2c11f143db1', 'FLOW_A_01', 'A', 'A片区流量监测点1'),
('5ba2a21d-fa45-4c20-a12b-a002b1da78ce', 'FLOW_A_02', 'A', 'A片区流量监测点2'),
('35ef1079-acec-4c42-86ea-c36d8d6bfd8a', 'FLOW_B_01', 'B', 'B片区流量监测点1'),
('0183f747-2423-48b6-a58f-df2dff22ab2b', 'FLOW_B_02', 'B', 'B片区流量监测点2'),
('674765fd-6109-41d9-8cd7-28bc8fd968af', 'FLOW_B_03', 'B', 'B片区流量监测点3'),
('42a6cb03-9446-4011-b820-ff671ec0fa86', 'FLOW_C_01', 'C', 'C片区流量监测点1'),
('9abd04b1-ff79-48cb-a44f-09f88124cd51', 'FLOW_C_02', 'C', 'C片区流量监测点2');

