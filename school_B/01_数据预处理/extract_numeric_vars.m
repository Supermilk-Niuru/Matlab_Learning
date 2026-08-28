function numMat = extract_numeric_vars(headers, rawData, numFields)
% EXTRACT_NUMERIC_VARS 任务5：提取数值字段，保持原值
%   数值字段（在网时长（月）、月费用、总费用）保持原始数值，
%   禁止标准化、归一化、对数转换或离散化。
%
%   缺失值处理：空字符串（如"总费用"在网时长为 0 的新客户缺失）→ NaN，
%   不做填充、不做删除，交由后续建模阶段决策。
%
%   输入：
%     headers   —— 字段名元胞数组
%     rawData   —— 原始数据元胞数组
%     numFields —— 数值字段名（元胞数组）
%   输出：
%     numMat —— M×K 数值矩阵，K 与 numFields 一一对应（double 类型）

M = size(rawData, 1);
K = numel(numFields);
numMat = zeros(M, K);

fprintf('-------- 任务5：数值字段保持原值（禁止标准化/归一化/离散化） --------\n');

for k = 1:K
    idx = find(strcmp(headers, numFields{k}), 1);
    if isempty(idx)
        error('[extract_numeric_vars] 未找到字段 "%s"。', numFields{k});
    end

    col = rawData(:, idx);
    % 非数值（空串 / 空格）经 str2double 后自动转为 NaN
    vals = cellfun(@str2double, col);
    numMat(:, k) = vals;

    fprintf('  %-12s : 保持原值（空值 %d 个 → NaN）\n', numFields{k}, sum(isnan(vals)));
end

fprintf('\n');

end
