function data = load_data()
% LOAD_DATA 读取 01_数据预处理/B_processed.csv（相对路径，自动检测文件）
%   输入：无
%   输出：
%     data —— 数据表 table（7043×20，含目标变量"是否流失"）
%
%   说明：仅读取，不修改原始数据。

scriptDir = fileparts(mfilename('fullpath'));
csvFile = fullfile(scriptDir, '..', '01_数据预处理', 'B_processed.csv');

if ~isfile(csvFile)
    error(['[load_data] 未找到数据文件：\n   %s\n' ...
           '请先运行 01_数据预处理/main_preprocess.m 生成该文件。'], csvFile);
end

data = readtable(csvFile, 'VariableNamingRule', 'preserve');

if ~ismember('是否流失', data.Properties.VariableNames)
    error('[load_data] 数据中缺少目标变量"是否流失"，请检查预处理输出。');
end

fprintf('-------- 数据读取 --------\n');
fprintf('数据规模：%d 行 × %d 列；目标变量"是否流失"：0=%d 人，1=%d 人\n\n', ...
        height(data), width(data), ...
        sum(data.('是否流失') == 0), sum(data.('是否流失') == 1));

end
