function [headers, rawData] = remove_id_column(headers, rawData, idFieldName)
% REMOVE_ID_COLUMN 任务2：删除无效字段（客户编码）
%   客户编码为每条样本的唯一身份标识，不参与数学建模，故删除。
%
%   输入：
%     headers     —— 字段名元胞数组
%     rawData     —— 原始数据元胞数组
%     idFieldName —— 需要删除的字段名（默认 '客户编码'）
%   输出：
%     headers —— 删除后的字段名元胞数组
%     rawData —— 删除后的数据元胞数组

idx = find(strcmp(headers, idFieldName), 1);
if isempty(idx)
    error('[remove_id_column] 未找到字段 "%s"，请检查原始数据。', idFieldName);
end

headers(idx)  = [];
rawData(:, idx) = [];

fprintf('-------- 任务2：删除无效字段 --------\n');
fprintf('已删除字段：%s（唯一身份标识，不参与建模）\n', idFieldName);
fprintf('删除后列数：%d\n\n', numel(headers));

end
