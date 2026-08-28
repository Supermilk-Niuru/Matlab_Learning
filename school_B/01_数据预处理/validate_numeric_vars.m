function validate_numeric_vars(headers, rawData, numFields, numMat)
% VALIDATE_NUMERIC_VARS 任务5校验：数值字段必须保持原值
%   逐列核对：处理后数值矩阵与"原始字符串→数值"转换结果完全一致
%   （含 NaN 位置），确保未发生任何标准化 / 归一化 / 离散化等变换。
%
%   输入：
%     headers   —— 字段名元胞数组
%     rawData   —— 原始数据元胞数组
%     numFields —— 数值字段名（元胞数组）
%     numMat    —— 当前处理后的数值矩阵

fprintf('-------- 任务5校验：数值字段未被修改 --------\n');

for k = 1:numel(numFields)
    idx = find(strcmp(headers, numFields{k}), 1);
    if isempty(idx)
        error('[validate_numeric_vars] 未找到字段 "%s"。', numFields{k});
    end

    expected = cellfun(@str2double, rawData(:, idx));
    if ~isequaln(numMat(:, k), expected)   % isequaln 认为 NaN 与 NaN 相等
        error('[validate_numeric_vars] 字段 "%s" 数值发生变化，请检查处理逻辑。', ...
              numFields{k});
    end
end

fprintf('校验通过：在网时长（月）、月费用、总费用 均保持原始数值，未做任何变换。\n\n');

end
