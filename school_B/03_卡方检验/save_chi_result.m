function save_chi_result(results, summaryTbl)
% SAVE_CHI_RESULT 保存卡方检验结果
%   1) 每个变量一个 Excel 文件：卡方检验详细结果/变量名.xlsx，含 4 个 Sheet：
%        Sheet1 Observed_Table   —— 观察频数列联表（含行和、列和）
%        Sheet2 Expected_Table   —— 理论频数矩阵
%        Sheet3 Chi_Contribution —— 每个单元格卡方贡献
%        Sheet4 Result           —— 样本量 / 卡方统计量 / 自由度 / p值 / 显著性
%   2) 汇总总表：卡方检验总表.xlsx（变量 / 卡方统计量 / 自由度 / p值 / 显著性）
%
%   输入：
%     results    —— N×1 结构体数组（字段：varName / obsTable / expTable /
%                   chiTable / resultTable）
%     summaryTbl —— 汇总表 table

detailDir = fullfile(pwd, '卡方检验详细结果');
if ~isfolder(detailDir)
    mkdir(detailDir);
end

fprintf('-------- 保存卡方检验结果 --------\n');

% 1) 每个变量一个详细 Excel（4 个 Sheet）
nVars = numel(results);
for i = 1:nVars
    xlsFile = fullfile(detailDir, [results(i).varName, '.xlsx']);
    if isfile(xlsFile)
        delete(xlsFile);
    end

    writetable(results(i).obsTable,   xlsFile, 'Sheet', 'Observed_Table',   'WriteMode', 'overwritesheet');
    writetable(results(i).expTable,   xlsFile, 'Sheet', 'Expected_Table',   'WriteMode', 'append');
    writetable(results(i).chiTable,   xlsFile, 'Sheet', 'Chi_Contribution', 'WriteMode', 'append');
    writetable(results(i).resultTable, xlsFile, 'Sheet', 'Result',           'WriteMode', 'append');

    fprintf('  已写入：%s（4 个 Sheet）\n', xlsFile);
end

% 2) 汇总总表
sumFile = fullfile(pwd, '卡方检验总表.xlsx');
if isfile(sumFile)
    delete(sumFile);
end
writetable(summaryTbl, sumFile, 'Sheet', 'Summary', 'WriteMode', 'overwritesheet');
fprintf('已保存总表：%s\n\n', sumFile);

end
