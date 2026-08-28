function out = build_contingency_table(data, varName, labelsMap)
% BUILD_CONTINGENCY_TABLE 构造"类别 × 是否流失"观察频数列联表
%   对分类变量 varName 的每个类别，统计未流失（编码 0）与流失（编码 1）人数，
%   并计算行和、列和与总人数。
%
%   输入：
%     data      —— B_processed 数据表
%     varName   —— 分类变量名称（中文，须与数据表字段一致）
%     labelsMap —— containers.Map：编码 → {原始类别名}；未映射时回退为数字编码
%   输出（结构体 out）：
%     out.O        —— r×2 观察频数矩阵（类别 × [未流失, 流失]）
%     out.rowNames —— r×1 元胞数组，类别名称
%     out.rowSums  —— r×1 行和
%     out.colSums  —— 1×2 列和
%     out.N        —— 总人数
%     out.obsTable —— 含行和与列和的完整列联表 table（供 Sheet1 使用）

churnCol = data.('是否流失');   % 目标变量
vcol     = data.(varName);      % 当前分类变量

codes = unique(vcol);           % 该变量实际出现的类别编码（升序）
r     = numel(codes);

O = zeros(r, 2);                % 观察频数矩阵
rowNames = cell(r, 1);

% 编码 → 原始类别名映射
meta = [];
if labelsMap.isKey(varName)
    meta = labelsMap(varName);
end

for c = 1:r
    mask = (vcol == codes(c));
    O(c, 1) = sum(mask & (churnCol == 0));   % 未流失数量
    O(c, 2) = sum(mask & (churnCol == 1));   % 流失数量

    % 未映射的编码回退为数字本身
    if ~isempty(meta)
        loc = find(meta.codes == codes(c), 1);
        if ~isempty(loc)
            rowNames{c} = meta.labels{loc};
        else
            rowNames{c} = num2str(codes(c));
        end
    else
        rowNames{c} = num2str(codes(c));
    end
end

rowSums = sum(O, 2);            % 行和（每类别合计）
colSums = sum(O, 1);            % 列和（未流失/流失合计）
N       = sum(rowSums);         % 总人数

% 完整列联表：类别 | 未流失数量 | 流失数量 | 行合计，末行为"合计"（列和）
catAll   = cat(1, rowNames(:), {'合计'});
notAug   = cat(1, O(:, 1), colSums(1));
churnAug = cat(1, O(:, 2), colSums(2));
totAug   = cat(1, rowSums, N);
obsTable = table(catAll, notAug, churnAug, totAug, ...
                 'VariableNames', {'类别', '未流失数量', '流失数量', '行合计'});

out.O        = O;
out.rowNames = rowNames(:);
out.rowSums  = rowSums;
out.colSums  = colSums;
out.N        = N;
out.obsTable = obsTable;

end
