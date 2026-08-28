%% preprocess_NIPT_data.m
% =========================================================================
% 2025年全国大学生数学建模竞赛 C题 问题1 —— NIPT数据预处理
%
% 任务范围：仅做数据预处理，不建立/训练任何数学模型。
%
% 功能流程：
%   1. 读取 Statistic.xlsx（含"男胎检测数据""女胎检测数据"两张工作表）
%   2. 查看数据规模、变量名称、数据类型
%   3. 整理数据：提取 孕妇ID、Y染色体浓度、孕周、BMI、胎儿性别 等关键变量
%   4. 孕周标准化（'11w+3' -> 11 + 3/7 = 11.43 周）
%   5. 基础清洗：删除关键变量缺失样本、数值类型转换、异常值检查
%   6. 初步区分男胎样本（Y染色体浓度仅男胎存在）
%   7. 输出清洗数据 clean_NIPT_data.xlsx
%   8. 汇总：清洗前后数据规模、最终保留变量列表
%
% 输出变量采用 ASCII 命名，以保证 fitlme 公式解析兼容性（中文变量名在
% 部分版本 fitlme 中可能引发解析问题）。中英文对应关系：
%   SubjectID   孕妇代码（随机效应分组变量）
%   Sex         胎儿性别（'男' / '女'）
%   Age         年龄
%   Visit       检测抽血次数（同一孕妇的重复测量序号）
%   GA_weeks    检测孕周（标准化数值，单位：周）
%   BMI         孕妇BMI
%   Y_conc      Y染色体浓度（因变量，仅男胎有值）
%   X_conc      X染色体浓度
%   OutlierFlag 异常值标记（1 = 该样本存在可疑异常值）
%
% 后续建模示例（本脚本不执行）：
%   cleanT = readtable('clean_NIPT_data.xlsx', 'Sheet', '男胎清洗数据');
%   lme = fitlme(cleanT, 'Y_conc ~ GA_weeks + BMI + (1 | SubjectID)');
% =========================================================================

clear; close all; clc;
rng('default');          % 固定随机种子，保证结果可复现

%% ==================== 0. 环境与参数设置 ====================
dataFile = fullfile(pwd, 'Statistic.xlsx');       % 原始数据文件
outFile  = fullfile(pwd, 'clean_NIPT_data.xlsx'); % 清洗后输出文件

% 工作表名称
SHEET_MALE   = '男胎检测数据';    % 原始：男胎
SHEET_FEMALE = '女胎检测数据';    % 原始：女胎
SHEET_MALE_OUT   = '男胎清洗数据';   % 输出：男胎建模数据（主）
SHEET_FEMALE_OUT = '女胎清洗数据';   % 输出：女胎参考数据

if ~exist(dataFile, 'file')
    error('未找到数据文件：%s', dataFile);
end

%% ==================== 1. 读取原始数据 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤1：读取 Excel 原始数据\n');
fprintf('%s\n', repmat('=', 1, 72));

% VariableNamingRule 设为 'preserve'，保留中文原始列名（默认会将其改为
% x__、x____ 等无效标识符，不利于查看与定位）
T_male_raw   = readtable(dataFile, 'Sheet', SHEET_MALE,   'VariableNamingRule', 'preserve');
T_female_raw = readtable(dataFile, 'Sheet', SHEET_FEMALE, 'VariableNamingRule', 'preserve');

fprintf('读取成功：\n');
fprintf('  [%s]：%d 行 × %d 列\n', SHEET_MALE,   height(T_male_raw),   width(T_male_raw));
fprintf('  [%s]：%d 行 × %d 列\n', SHEET_FEMALE, height(T_female_raw), width(T_female_raw));
fprintf('  合计：%d 行 × %d 列\n', ...
        height(T_male_raw) + height(T_female_raw), width(T_male_raw));

%% ==================== 2. 查看数据基本信息 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤2：数据总行数、总列数、变量名称与数据类型\n');
fprintf('%s\n', repmat('=', 1, 72));

report_table_info(T_male_raw,   '男胎检测数据');
report_table_info(T_female_raw, '女胎检测数据');

%% ==================== 3. 整理数据：提取关键变量并合并 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤3：整理数据 —— 提取关键变量、合并两张表、增加胎儿性别列\n');
fprintf('%s\n', repmat('=', 1, 72));

% 关键变量：
%   孕妇代码  -> 后续 fitlme 的随机效应分组变量
%   Y染色体浓度 -> 因变量
%   检测孕周  -> 预测变量（标准化为数值周）
%   孕妇BMI   -> 预测变量
%   胎儿性别  -> 由工作表来源决定（男 / 女）
%   另保留 年龄、检测抽血次数、X染色体浓度 供后续建模参考
T_male_key   = extract_key_vars(T_male_raw,   '男');
T_female_key = extract_key_vars(T_female_raw, '女');

% 纵向合并两张表
T_all = [T_male_key; T_female_key];
fprintf('合并后全量数据：%d 行 × %d 列\n', height(T_all), width(T_all));
fprintf('变量列表：\n');
for k = 1:width(T_all)
    fprintf('  %-12s（%s）\n', T_all.Properties.VariableNames{k}, ...
            var_desc(T_all.Properties.VariableNames{k}));
end

%% ==================== 4. 孕周标准化处理 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤4：孕周标准化 —— ''12w+3'' -> 12 + 3/7 = 12.43 周\n');
fprintf('%s\n', repmat('=', 1, 72));

% 展示标准化示例（前5个有效样本）
exIdx = find(~isnan(T_all.GA_weeks), 5);
for i = 1:numel(exIdx)
    fprintf('  %-8s -> %.3f 周\n', T_all.GA_raw(exIdx(i)), T_all.GA_weeks(exIdx(i)));
end
nBadGA = nnz(isnan(T_all.GA_weeks));
if nBadGA > 0
    fprintf('  警告：有 %d 条孕周无法解析（将被视为缺失）\n', nBadGA);
else
    fprintf('  全部孕周均已成功标准化。\n');
end

%% ==================== 5. 数据清洗：缺失值 + 异常值 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤5：基础清洗 —— 缺失值删除、异常值检查\n');
fprintf('%s\n', repmat('=', 1, 72));

% 5.1 删除关键变量缺失的样本
%     关键变量：孕妇代码、孕周、BMI、性别。
%     注意：Y染色体浓度对女胎天然缺失（无Y染色体），此处不删；
%           男胎若Y浓度缺失，将在步骤6区分男胎后单独处理。
[T_all, nDropped] = clean_missing(T_all);
fprintf('删除关键变量缺失样本：%d 行\n', nDropped);
fprintf('清洗后全量数据：%d 行\n', height(T_all));

% 5.2 异常值检查（仅报告与标记，不删除）
%     连续变量用箱线图准则 [Q1-1.5IQR, Q3+1.5IQR]；
%     孕周用生物学合理范围 [10, 30] 周检查。
contVars = {'Age', 'BMI', 'Y_conc', 'X_conc'};
T_all = flag_outliers(T_all, contVars, 'GA_weeks');

%% ==================== 6. 初步区分男胎样本 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤6：初步区分男胎样本（Y染色体浓度仅男胎存在）\n');
fprintf('%s\n', repmat('=', 1, 72));

T_male   = T_all(T_all.Sex == '男', :);   % 男胎：用于后续建模
T_female = T_all(T_all.Sex == '女', :);   % 女胎：作为参考数据

% 防御性检查：男胎的Y染色体浓度必须非空
nYmiss = nnz(isnan(T_male.Y_conc));
if nYmiss > 0
    fprintf('  警告：%d 个男胎样本Y染色体浓度缺失，予以删除\n', nYmiss);
    T_male = T_male(~isnan(T_male.Y_conc), :);
end
fprintf('  男胎样本（供建模）：%d 行\n', height(T_male));
fprintf('  女胎样本（参考）  ：%d 行\n', height(T_female));

% 去除临时列 GA_raw（仅保留标准化数值），保证输出表可直接用于 fitlme
T_male.GA_raw   = [];
T_female.GA_raw = [];

%% ==================== 7. 保存清洗后的数据 ====================
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤7：保存清洗数据 -> %s\n', outFile);
fprintf('%s\n', repmat('=', 1, 72));

if exist(outFile, 'file'), delete(outFile); end   % 避免残留旧工作表
writetable(T_male,   outFile, 'Sheet', SHEET_MALE_OUT);
writetable(T_female, outFile, 'Sheet', SHEET_FEMALE_OUT);

fprintf('已保存。工作表内容：\n');
fprintf('  [%s]：男胎建模数据，%d 行 × %d 列\n', SHEET_MALE_OUT,   height(T_male),   width(T_male));
fprintf('  [%s]：女胎参考数据，%d 行 × %d 列\n', SHEET_FEMALE_OUT, height(T_female), width(T_female));

%% ==================== 8. 结果汇总 ====================
print_summary(T_male_raw, T_female_raw, T_male, T_female);

% =========================================================================
% 以下为局部函数（模块化）
% =========================================================================

%% 局部函数：报表基本信息（行数、列数、变量名、类型、缺失数）
function report_table_info(T, label)
    varNames = T.Properties.VariableNames;
    fprintf('\n[%s] 规模：%d 行 × %d 列\n', label, height(T), width(T));
    fprintf('%-6s  %-32s  %-10s  %-8s\n', '列号', '变量名', '数据类型', '缺失数');
    fprintf('%s\n', repmat('-', 1, 72));
    for k = 1:numel(varNames)
        col = T{:, k};
        fprintf('%-6d  %-32s  %-10s  %-8d\n', ...
                k, varNames{k}, classify_type(col), count_missing(col));
    end
end

%% 局部函数：判断变量数据类型
function dtype = classify_type(x)
    if isa(x, 'datetime')
        dtype = '日期型';
    elseif isa(x, 'duration')
        dtype = '时间型';
    elseif islogical(x)
        dtype = '逻辑型';
    elseif isnumeric(x)
        dtype = '数值型';
    elseif isstring(x) || iscell(x)
        dtype = '字符型';
    else
        dtype = class(x);
    end
end

%% 局部函数：统计缺失个数
function n = count_missing(x)
    if isstring(x)
        n = nnz(ismissing(x));
    elseif isnumeric(x) || islogical(x)
        n = nnz(isnan(x));
    elseif iscell(x)
        n = nnz(cellfun(@(c) isempty(c) || (ischar(c) && isempty(strtrim(c))), x));
    else
        n = nnz(ismissing(x));
    end
end

%% 局部函数：关键变量在原始表中的列号布局（A=1, B=2, ..., AE=31）
function L = col_layout()
    L.ID    = 2;   % 孕妇代码
    L.AGE   = 3;   % 年龄
    L.VISIT = 9;   % 检测抽血次数
    L.GA    = 10;  % 检测孕周（字符型，如 '11w+3'）
    L.BMI   = 11;  % 孕妇BMI
    L.YC    = 22;  % Y染色体浓度（因变量）
    L.XC    = 23;  % X染色体浓度
end

%% 局部函数：从一张原始工作表提取关键变量，构建统一表结构
function T = extract_key_vars(T_raw, sex)
    L = col_layout();

    % 按列号提取关键变量
    ID      = string(T_raw{:, L.ID});       % 孕妇代码 -> 字符型
    Age     = numericize(T_raw{:, L.AGE});  % 年龄
    Visit   = numericize(T_raw{:, L.VISIT});% 检测抽血次数
    GA_raw  = string(T_raw{:, L.GA});       % 孕周原始文本
    BMI     = numericize(T_raw{:, L.BMI});  % 孕妇BMI
    Yconc   = numericize(T_raw{:, L.YC});   % Y染色体浓度
    Xconc   = numericize(T_raw{:, L.XC});   % X染色体浓度

    % 孕周标准化（'11w+3' -> 11.43 周）
    GA_weeks = standardize_GA(GA_raw);

    % 组装为标准表结构
    T = table(ID, Age, Visit, GA_raw, GA_weeks, BMI, Yconc, Xconc);
    T.Sex = repmat(string(sex), height(T), 1);   % 胎儿性别（由工作表来源决定）

    % 重命名为 ASCII 名称，保证 fitlme 公式兼容
    T.Properties.VariableNames = ...
        {'SubjectID', 'Age', 'Visit', 'GA_raw', 'GA_weeks', 'BMI', ...
         'Y_conc', 'X_conc', 'Sex'};
end

%% 局部函数：统一转换为数值向量（double），无法转换的置为 NaN
function x = numericize(x)
    if iscell(x) || ischar(x)
        x = string(x);
    end
    if isstring(x)
        x = str2double(x);   % 非数字字符串 -> NaN
    else
        x = double(x);
    end
end

%% 局部函数：孕周标准化
%  支持格式：
%    '11w'      -> 11 周
%    '11w+3'    -> 11 + 3/7 = 11.43 周
%    '16W+1'    -> 大小写均可
%    '11周'     -> 中文格式
%    '11周+3天' -> 中文格式
function ga = standardize_GA(ga_raw)
    s  = strtrim(string(ga_raw));      % 去除首尾空白
    n  = numel(s);
    ga = NaN(n, 1);
    % 正则：可选 '+'，可选天数部分
    pat = '(\d+)\s*[wW周]\s*\+?\s*(\d*)\s*[dD天]?';
    for i = 1:n
        if strlength(s(i)) == 0
            continue;                  % 空值 -> NaN
        end
        tok = regexp(s(i), pat, 'tokens', 'once');
        if isempty(tok)
            continue;                  % 无法解析 -> NaN
        end
        w = str2double(tok{1});        % 周数
        d = str2double(tok{2});        % 天数
        if isnan(d), d = 0; end        % 无天数
        if d >= 7                      % 防御：天数进位
            w = w + floor(d / 7);
            d = mod(d, 7);
        end
        ga(i) = w + d / 7;             % 换算为小数周
    end
end

%% 局部函数：删除关键变量缺失的样本
%  关键变量：孕妇代码、孕周、BMI、性别。
%  Y_conc 女胎天然缺失，此处不删；男胎Y_conc缺失在男胎筛选后单独处理。
function [T, nDropped] = clean_missing(T)
    keyCols = {'SubjectID', 'GA_weeks', 'BMI', 'Sex'};
    keep = true(height(T), 1);
    for k = 1:numel(keyCols)
        col = T.(keyCols{k});
        if isstring(col)
            miss = ismissing(col) | (strlength(col) == 0);
        else
            miss = isnan(col);
        end
        keep = keep & ~miss;
    end
    nDropped = nnz(~keep);
    T = T(keep, :);
end

%% 局部函数：异常值检查（仅标记，不删除）
%  连续变量：箱线图准则 [Q1-1.5IQR, Q3+1.5IQR]
%  孕周     ：生物学合理范围检查
function T = flag_outliers(T, contVars, gaVar)
    flag = false(height(T), 1);
    fprintf('  异常值检查（仅标记不删除）：\n');
    fprintf('  %-14s  %-10s  %-24s\n', '变量', '异常值个数', '正常范围');
    fprintf('  %s\n', repmat('-', 1, 60));
    for k = 1:numel(contVars)
        x   = T.(contVars{k});
        q1  = prctile(x, 25);          % 下四分位数（自动忽略NaN）
        q3  = prctile(x, 75);          % 上四分位数
        iqr = q3 - q1;
        lo  = q1 - 1.5 * iqr;          % 下界
        hi  = q3 + 1.5 * iqr;          % 上界
        isOut = ~isnan(x) & (x < lo | x > hi);
        flag = flag | isOut;
        fprintf('  %-14s  %-10d  [%.4f, %.4f]\n', ...
                contVars{k}, nnz(isOut), lo, hi);
    end
    % 孕周合理性检查（NIPT 常规检测窗口约为 11~30 周）
    gLo = 10;  gHi = 30;
    g   = T.(gaVar);
    gOut = ~isnan(g) & (g < gLo | g > gHi);
    flag = flag | gOut;
    fprintf('  %-14s  %-10d  [%d, %d]\n', gaVar, nnz(gOut), gLo, gHi);
    T.OutlierFlag = flag;
end

%% 局部函数：变量中文说明
function d = var_desc(vname)
    switch vname
        case 'SubjectID', d = '孕妇代码（随机效应分组）';
        case 'Sex',       d = '胎儿性别';
        case 'Age',       d = '年龄';
        case 'Visit',     d = '检测抽血次数';
        case 'GA_raw',    d = '孕周原始文本（临时列，输出时删除）';
        case 'GA_weeks',  d = '孕周（标准化数值，周）';
        case 'BMI',       d = '孕妇BMI';
        case 'Y_conc',    d = 'Y染色体浓度（因变量）';
        case 'X_conc',    d = 'X染色体浓度';
        case 'OutlierFlag', d = '异常值标记';
        otherwise,        d = '';
    end
end

%% 局部函数：结果汇总
function print_summary(T_male_raw, T_female_raw, T_male, T_female)
    fprintf('%s\n', repmat('=', 1, 72));
    fprintf('============== 结果汇总 ==============\n');

    fprintf('一、清洗前数据规模：\n');
    fprintf('  [%s]：%d 行\n', '男胎检测数据', height(T_male_raw));
    fprintf('  [%s]：%d 行\n', '女胎检测数据', height(T_female_raw));
    fprintf('  合计：%d 行\n', height(T_male_raw) + height(T_female_raw));

    fprintf('二、清洗后数据规模：\n');
    fprintf('  全量（缺失清理后）：%d 行\n', height(T_male) + height(T_female));
    fprintf('  男胎（供 fitlme 建模）：%d 行\n', height(T_male));
    fprintf('  女胎（参考）        ：%d 行\n', height(T_female));

    fprintf('三、最终保留变量列表（ASCII命名以兼容 fitlme）：\n');
    varMap = {'SubjectID', '孕妇代码（随机效应分组变量）';
              'Sex',       '胎儿性别';
              'Age',       '年龄';
              'Visit',     '检测抽血次数（个体内重复测量序号）';
              'GA_weeks',  '检测孕周（标准化数值，单位：周）';
              'BMI',       '孕妇BMI';
              'Y_conc',    'Y染色体浓度（因变量）';
              'X_conc',    'X染色体浓度';
              'OutlierFlag','异常值标记'};
    for k = 1:size(varMap, 1)
        fprintf('  %-12s -> %s\n', varMap{k, 1}, varMap{k, 2});
    end

    fprintf('四、fitlme 使用示例（后续建模，本脚本不执行）：\n');
    fprintf('  cleanT = readtable(''clean_NIPT_data.xlsx'', ''Sheet'', ''男胎清洗数据'');\n');
    fprintf('  lme = fitlme(cleanT, ''Y_conc ~ GA_weeks + BMI + (1 | SubjectID)'');\n');
    fprintf('%s\n', repmat('=', 1, 72));
end
