%% main_preprocess.m —— 电信客户流失分析：数据预处理主程序
%  功能：读取 B.csv → 基础数据清洗与格式转换
%        （删除无效字段、二分类 0/1 转换、多分类编码、
%          数值字段保持原值）→ 输出 B_processed.csv 与 encoding_rule.xlsx
%  说明：本阶段仅进行基础数据清洗与格式转换，
%        不进行特征工程、标准化、归一化、特征选择等任何模型相关处理。
%  环境：MATLAB R2020b 及以上
%  依赖函数：read_raw_data / remove_id_column / convert_binary_vars /
%            encode_categorical_vars / extract_numeric_vars /
%            validate_numeric_vars / save_processed_data
%
%  运行方式：在 MATLAB 命令行直接执行  main_preprocess

clc; clear; close all;

%% ---------- 0) 定位工作目录（避免硬编码路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end
rawFile = fullfile(pwd, 'B.csv');

% 自动检测原始数据文件是否存在
if ~isfile(rawFile)
    error(['[main_preprocess] 未找到原始数据文件：%s\n' ...
           '请确认 B.csv 已放在当前目录下。'], rawFile);
end

fprintf('========================================\n');
fprintf('  电信客户流失分析 —— 数据预处理\n');
fprintf('========================================\n\n');

%% ---------- 任务1：读取数据 ----------
[headers, rawData, enc] = read_raw_data(rawFile);
fprintf('[提示] 检测到文件编码：%s\n\n', enc);

%% ---------- 任务2：删除无效字段（客户编码） ----------
[headers, rawData] = remove_id_column(headers, rawData, '客户编码');

%% ---------- 任务3：二分类变量 是/否 → 0/1 ----------
% 12 个二分类特征 + 1 个目标变量（是否流失）
binaryFields = {
    '是否为老年人'
    '是否有伴侣'
    '是否有家属'
    '是否开通电话服务'
    '是否开通多条线路'
    '是否开通在线安全'
    '是否开通在线备份'
    '是否开通设备保护'
    '是否开通技术支持'
    '是否开通电视流媒体'
    '是否开通电影流媒体'
    '是否使用电子账单'
    '是否流失'                       % 目标变量
    };
binMat = convert_binary_vars(headers, rawData, binaryFields);

%% ---------- 任务4：多分类变量编码 ----------
catFields = {'性别', '互联网服务类型', '合同类型', '支付方式'};
[catMat, encRules] = encode_categorical_vars(headers, rawData, catFields);

%% ---------- 任务5：数值字段保持原值 ----------
numFields = {'在网时长（月）', '月费用', '总费用'};
numMat = extract_numeric_vars(headers, rawData, numFields);
validate_numeric_vars(headers, rawData, numFields, numMat);

%% ---------- 按原始字段顺序组装输出表（全部为数值） ----------
% 定位各字段在原始顺序中的列号，再回填对应编码结果，
% 保证字段顺序与原始数据一致。
colIdx = @(fieldList) cell2mat(cellfun(@(f) find(strcmp(headers, f), 1), ...
                                       fieldList(:), 'UniformOutput', false)).';

idxBin = colIdx(binaryFields);
idxCat = colIdx(catFields);
idxNum = colIdx(numFields);

% 校验：所有字段均已覆盖，未遗漏
assert(isequal(sort([idxBin, idxCat, idxNum]), 1:numel(headers)), ...
       '[main_preprocess] 字段覆盖不完整，请检查字段清单。');

outMat = zeros(size(rawData, 1), numel(headers));
outMat(:, idxBin) = binMat;
outMat(:, idxCat) = catMat;
outMat(:, idxNum) = numMat;

% 组装为表格，表头保留中文字段名
outTable = array2table(outMat);
outTable.Properties.VariableNames = headers;

%% ---------- 任务6：保存结果 ----------
save_processed_data(outTable, encRules);

%% ---------- 结束 ----------
fprintf('========================================\n');
fprintf('  数据处理完成！\n');
fprintf('  输出文件：B_processed.csv  /  encoding_rule.xlsx\n');
fprintf('========================================\n');
