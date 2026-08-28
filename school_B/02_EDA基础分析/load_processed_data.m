function data = load_processed_data()
% LOAD_PROCESSED_DATA 读取预处理后的数据 B_processed.csv
%   要求：
%     - 保留中文字段名称（VariableNamingRule = 'preserve'）
%     - 输出数据规模与字段名称
%     - 自动检测文件是否存在
%
%   输出：
%     data —— table，行为样本、列为变量（中文字段名）

% 数据文件位于上一级目录的 01_数据预处理 文件夹中（相对路径，避免硬编码）
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
filePath = fullfile(scriptDir, '..', '01_数据预处理', 'B_processed.csv');

% 自动检测文件是否存在
if ~isfile(filePath)
    error(['[load_processed_data] 未找到数据文件：%s\n' ...
           '请先运行 01_数据预处理/main_preprocess.m 生成 B_processed.csv。'], filePath);
end

% 读取，保留中文表头
data = readtable(filePath, 'VariableNamingRule', 'preserve');

fprintf('-------- 数据读取 --------\n');
fprintf('数据规模：%d 行 × %d 列\n', size(data, 1), size(data, 2));
fprintf('字段名称：\n');
for i = 1:width(data)
    fprintf('  %2d. %s\n', i, data.Properties.VariableNames{i});
end
fprintf('\n');

end
