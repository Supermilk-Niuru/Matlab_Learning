function save_F_result(resAll, summaryTbl)
% SAVE_F_RESULT 保存单因素方差分析（F 检验）结果
%   1) 每个变量一个 Excel 文件：各类变量F检验详细结果/变量名.xlsx，含 4 个 Sheet：
%        Sheet1 描述统计         —— 流失状态 / 样本数量 / 均值 / 标准差
%        Sheet2 平方和计算过程   —— 总体均值 / SST / SSA / SSE / SSA+SSE / 分解误差
%        Sheet3 ANOVA表          —— 来源 / 平方和 / 自由度 / 均方 / F值 / p值
%        Sheet4 检验结论         —— 变量名称 / F统计量 / df1 / df2 / p值 / 显著性
%   2) 汇总总表：F检验总表.xlsx（变量名称 / F值 / df1 / df2 / p值 / 是否显著）
%
%   输入：
%     resAll     —— N×1 结构体数组（字段：varName / descTbl / sqTbl /
%                   anovaTbl / conclTbl）
%     summaryTbl —— 汇总表 table

detailDir = fullfile(pwd, '各类变量F检验详细结果');
if ~isfolder(detailDir)
    mkdir(detailDir);
end

fprintf('-------- 保存F检验结果 --------\n');

% 1) 每个变量一个详细 Excel（4 个 Sheet）
nVars = numel(resAll);
for i = 1:nVars
    xlsFile = fullfile(detailDir, [resAll(i).varName, '.xlsx']);
    if isfile(xlsFile)
        delete(xlsFile);
    end

    writetable(resAll(i).descTbl,  xlsFile, 'Sheet', '描述统计',       'WriteMode', 'overwritesheet');
    writetable(resAll(i).sqTbl,    xlsFile, 'Sheet', '平方和计算过程', 'WriteMode', 'append');
    writetable(resAll(i).anovaTbl, xlsFile, 'Sheet', 'ANOVA表',         'WriteMode', 'append');
    writetable(resAll(i).conclTbl, xlsFile, 'Sheet', '检验结论',        'WriteMode', 'append');

    fprintf('  已写入：%s（4 个 Sheet）\n', xlsFile);
end

% 2) 汇总总表
sumFile = fullfile(pwd, 'F检验总表.xlsx');
if isfile(sumFile)
    delete(sumFile);
end
writetable(summaryTbl, sumFile, 'Sheet', 'Summary', 'WriteMode', 'overwritesheet');
fprintf('已保存总表：%s\n\n', sumFile);

end
