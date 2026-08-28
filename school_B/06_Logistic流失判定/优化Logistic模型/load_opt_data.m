function [data, origRow] = load_opt_data()
% LOAD_OPT_DATA 读取预处理后的数据并删除总费用缺失样本（优化模型专用）
%   相对路径读取 ../../01_数据预处理/B_processed.csv（7043×20）。
%   与原始 Logistic 模型完全一致：
%     删除总费用缺失（NaN）的 11 行，剩余有效样本 7032 行。
%   本程序不修改原始数据 B_processed.csv。
%
%   输入：无
%   输出：
%     data    —— 删除缺失样本后的数据表（readtable, VariableNamingRule='preserve'）
%     origRow —— 保留样本在 B_processed.csv 中的原始行号（N×1，作为"客户编号"）

%% 1) 定位并读取数据文件
% 本脚本位于 06_Logistic流失判定/优化Logistic模型/，
% 数据文件在 ../../01_数据预处理/B_processed.csv
csvFile = fullfile(pwd, '..', '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error('[load_opt_data] 未找到数据文件：%s\n请先运行 01_数据预处理/main_preprocess.m。', csvFile);
end
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
fprintf('读取数据：%d 行 × %d 列\n', size(data, 1), size(data, 2));

%% 2) 删除总费用缺失（NaN）的样本（与原始 Logistic 模型一致）
bad = isnan(data.('总费用'));
origRow = find(~bad);            % 保留样本的原始行号 = 客户编号
data(bad, :) = [];
fprintf('删除总费用缺失样本 %d 行，剩余有效样本 %d 行（与原始 Logistic 模型一致）。\n', ...
    sum(bad), height(data));

end
