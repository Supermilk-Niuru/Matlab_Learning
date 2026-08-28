function save_EDA_result(overallTbl, catResult, numericTbl)
% SAVE_EDA_RESULT 将 EDA 分析结果保存为 Excel 文件 EDA_basic_result.xlsx
%
%   Sheet 结构：
%     Overall_Churn            —— 步骤一：整体流失统计（状态 | 数量 | 比例）
%     <英文名>_Churn（16个）    —— 步骤二：各分类变量单因素流失统计
%     Numeric_Churn_Comparison —— 步骤三：连续变量分组统计
%
%   输入：
%     overallTbl —— 整体流失统计表
%     catResult  —— N×2 元胞数组 {Sheet名, 统计表}（步骤二）
%     numericTbl —— 连续变量统计表（步骤三）

xlsFile = fullfile(pwd, 'EDA_basic_result.xlsx');

% 删除旧文件，避免残留旧 Sheet
if isfile(xlsFile)
    delete(xlsFile);
end

fprintf('-------- 保存 Excel 分析结果 --------\n');

% 1) 步骤一：整体流失
writetable(overallTbl, xlsFile, 'Sheet', 'Overall_Churn', 'WriteMode', 'overwritesheet');
fprintf('  已写入 Sheet：Overall_Churn\n');

% 2) 步骤二：各分类变量
for i = 1:size(catResult, 1)
    writetable(catResult{i, 2}, xlsFile, 'Sheet', catResult{i, 1}, 'WriteMode', 'append');
    fprintf('  已写入 Sheet：%s\n', catResult{i, 1});
end

% 3) 步骤三：连续变量
writetable(numericTbl, xlsFile, 'Sheet', 'Numeric_Churn_Comparison', 'WriteMode', 'append');
fprintf('  已写入 Sheet：Numeric_Churn_Comparison\n');

fprintf('已保存 Excel 分析结果：%s\n\n', xlsFile);

end
