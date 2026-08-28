%% main_chi_square.m —— 电信客户流失分析：分类因素卡方独立性检验（手动计算全过程）
%  功能：读取 01_数据预处理/B_processed.csv →
%        对全部 16 个分类变量（不含"是否流失"）手动完成卡方独立性检验：
%          ① 构造观察频数列联表 O（含行和、列和）
%          ② 计算理论频数矩阵 E = (行和_i × 列和_j) / N
%          ③ 计算每个单元格卡方贡献 C_ij = (O_ij - E_ij)² / E_ij
%          ④ 求和得到卡方统计量 χ² = Σ C_ij
%          ⑤ 由自由度 df 计算 p 值（高精度上尾概率，极小 p 值以科学计数法保存，不显示为 0）
%        → 每个变量生成 卡方检验详细结果/变量名.xlsx（4 个 Sheet）
%        → 生成 卡方检验总表.xlsx
%
%  说明：本阶段仅做统计分析，
%        不训练机器学习模型、不预测客户流失、不进行特征选择、
%        不修改原始数据、不进行标准化/归一化。
%        不使用 chi2gof / chi2cdf / crosstab 等现成卡方结果函数，
%        全部计算过程（列联表、理论频数、卡方贡献、卡方统计量、p 值）手动实现。
%
%  环境：MATLAB R2025a（仅使用基础函数，不依赖统计工具箱）
%  依赖函数：build_contingency_table / calculate_expected_table /
%            chi_square_manual / save_chi_result
%  运行方式：在 MATLAB 命令行直接执行  main_chi_square

clc; clear; close all;

%% ---------- 0) 定位工作目录（避免绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

%% ---------- 1) 读取数据（相对路径，自动检测文件） ----------
csvFile = fullfile(scriptDir, '..', '01_数据预处理', 'B_processed.csv');
if ~isfile(csvFile)
    error(['[main_chi_square] 未找到数据文件：\n   %s\n' ...
           '请先运行 01_数据预处理/main_preprocess.m 生成该文件。'], csvFile);
end
data = readtable(csvFile, 'VariableNamingRule', 'preserve');
if ~ismember('是否流失', data.Properties.VariableNames)
    error('[main_chi_square] 数据中缺少目标变量"是否流失"，请检查预处理输出。');
end
fprintf('-------- 数据读取 --------\n');
fprintf('数据规模：%d 行 × %d 列；目标变量"是否流失"：0=%d 人，1=%d 人\n\n', ...
        height(data), width(data), ...
        sum(data.('是否流失') == 0), sum(data.('是否流失') == 1));

%% ---------- 2) 分类变量清单（不含"是否流失"） ----------
varList = {
    '性别'                              % 客户属性
    '是否为老年人'
    '是否有伴侣'
    '是否有家属'
    '是否开通电话服务'                  % 电话服务
    '是否开通多条线路'
    '互联网服务类型'                    % 互联网及增值服务
    '是否开通在线安全'
    '是否开通在线备份'
    '是否开通设备保护'
    '是否开通技术支持'
    '是否开通电视流媒体'
    '是否开通电影流媒体'
    '合同类型'                          % 合同与支付
    '是否使用电子账单'
    '支付方式'
    };

%% ---------- 3) 类别标签（编码 → 原始类别名，与 encoding_rule.xlsx 一致） ----------
labelsMap = containers.Map();
labelsMap('性别')            = struct('codes', [0 1],     'labels', {{'女', '男'}});
labelsMap('是否为老年人')      = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否有伴侣')        = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否有家属')        = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否开通电话服务')   = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('是否开通多条线路')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通电话服务'}});
labelsMap('互联网服务类型')     = struct('codes', [0 1 2],   'labels', {{'无', 'DSL', 'Fiber optic'}});
labelsMap('是否开通在线安全')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通在线备份')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通设备保护')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通技术支持')   = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通电视流媒体') = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('是否开通电影流媒体') = struct('codes', [0 1 2],   'labels', {{'否', '是', '未开通互联网服务'}});
labelsMap('合同类型')          = struct('codes', [0 1 2],   'labels', {{'Month-to-month', 'One year', 'Two year'}});
labelsMap('是否使用电子账单')   = struct('codes', [0 1],     'labels', {{'否', '是'}});
labelsMap('支付方式')          = struct('codes', [1 2 3 4], 'labels', {{'Bank transfer (automatic)', 'Credit card (automatic)', 'Electronic check', 'Mailed check'}});

%% ---------- 4) 显著性水平 ----------
alpha = 0.05;

%% ---------- 5) 逐变量手动卡方检验 ----------
nVars = numel(varList);

% 结果结构体数组（供 save_chi_result 保存）
emptyRes = struct('varName', [], 'obsTable', [], 'expTable', [], ...
                  'chiTable', [], 'resultTable', []);
results = repmat(emptyRes, nVars, 1);

% 汇总表数据
chi2All  = zeros(nVars, 1);
dfAll    = zeros(nVars, 1);
pStrAll  = cell(nVars, 1);   % p 值科学计数法字符串
sigAll   = cell(nVars, 1);

fprintf('========================================\n');
fprintf('  分类因素卡方独立性检验（α = %.2f）\n', alpha);
fprintf('========================================\n');
fprintf('%-14s %12s %6s %18s %8s\n', '变量名称', '卡方统计量', '自由度', 'p值', '显著性');
fprintf('%s\n', repmat('-', 1, 62));

for i = 1:nVars
    varName = varList{i};

    % 字段存在性检查
    if ~ismember(varName, data.Properties.VariableNames)
        error('[main_chi_square] 数据中不存在字段 "%s"。', varName);
    end

    % ① 构造观察频数列联表（含行和、列和）
    ct = build_contingency_table(data, varName, labelsMap);
    O  = ct.O;

    % 校验：列联表总人数必须等于样本数 7043
    if ct.N ~= height(data)
        warning('[main_chi_square] "%s" 列联表总人数 %d ≠ 总样本数 %d，请检查编码。', ...
                varName, ct.N, height(data));
    end

    % ② 理论频数矩阵 E = (行和 × 列和) / N
    E = calculate_expected_table(O);

    % ③④⑤⑥ 单元格卡方贡献、卡方统计量、自由度、高精度 p 值、显著性
    [chi2, df, p, C, sig] = chi_square_manual(O, E, alpha);

    % p 值科学计数法字符串（禁止把极小 p 值显示成 0）
    pStr = sprintf('%.6E', p);

    chi2All(i) = chi2;
    dfAll(i)   = df;
    pStrAll{i} = pStr;
    sigAll{i}  = sig;

    % 构造 4 个 Sheet 所需的数据表
    results(i).varName  = varName;
    results(i).obsTable = ct.obsTable;   % Sheet1 观察频数 + 行和 + 列和
    results(i).expTable = table(ct.rowNames, E(:, 1), E(:, 2), ...
        'VariableNames', {'类别', '未流失期望频数', '流失期望频数'});   % Sheet2 理论频数矩阵
    results(i).chiTable = table(ct.rowNames, C(:, 1), C(:, 2), ...
        'VariableNames', {'类别', '未流失贡献', '流失贡献'});           % Sheet3 每单元格卡方贡献
    results(i).resultTable = table(ct.N, chi2, df, {pStr}, {sig}, ...
        'VariableNames', {'样本量', '卡方统计量', '自由度', 'p值', '显著性'});  % Sheet4 结果

    % 控制台输出
    fprintf('%-14s %12.4f %6d %18s %8s\n', varName, chi2, df, pStr, sig);
end

%% ---------- 6) 汇总表 ----------
summaryTbl = table(varList, chi2All, dfAll, pStrAll, sigAll, ...
                   'VariableNames', {'变量', '卡方统计量', '自由度', 'p值', '显著性'});

%% ---------- 7) 保存 Excel 结果 ----------
save_chi_result(results, summaryTbl);

%% ---------- 8) 完成 ----------
fprintf('========================================\n');
fprintf('  分类因素卡方检验完成。\n');
fprintf('  共检验 %d 个分类变量，其中显著（p < 0.05）%d 个，不显著 %d 个。\n', ...
        nVars, sum(strcmp(sigAll, '显著')), sum(strcmp(sigAll, '不显著')));
fprintf('  详细结果目录：%s\n', fullfile(pwd, '卡方检验详细结果'));
fprintf('  汇总总表：%s\n', fullfile(pwd, '卡方检验总表.xlsx'));
fprintf('========================================\n');
