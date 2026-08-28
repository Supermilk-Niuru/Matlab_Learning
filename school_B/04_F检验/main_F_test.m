%% main_F_test.m —— 电信客户流失分析：单因素方差分析（One-way ANOVA，F检验）
%  功能：读取 01_数据预处理/B_processed.csv →
%        对所有影响流失的因素（16 个分类变量 + 3 个连续变量）手动完成单因素方差分析：
%          按"是否流失"分成 2 组（k=2），检验各组变量的均值是否存在显著差异。
%          ① 各组样本均值 ② 总体均值 ③ 总离差平方和 SST
%          ④ 组间平方和 SSA ⑤ 组内平方和 SSE ⑥ 验证 SST = SSA + SSE
%          ⑦ 组间均方 MSA ⑧ 组内均方 MSE ⑨ F = MSA/MSE，由 F(df1,df2) 算 p 值
%        → 每个变量生成 各类变量F检验详细结果/变量名.xlsx（4 个 Sheet）
%        → 生成 F检验总表.xlsx
%
%  说明：本阶段仅做统计检验。
%        不训练机器学习模型、不预测客户流失、不进行特征选择、
%        不修改原始数据、不进行标准化/归一化。
%        不使用 anova1 / fcdf 等现成函数，全部计算过程（平方和、均方、
%        F 统计量、p 值）手动实现；p 值在对数空间计算，极小值不归零。
%
%  变量管理（A 类在前，B 类在后）：
%    A. 分类变量（16 个）——性别、年龄、家庭、电话/互联网/增值服务、
%                           合同类型、账单、支付方式等，按其编码取值
%                           参与均值比较（二分类时均值即取 1 的比例）；
%    B. 连续变量（3 个）——在网时长（月）、月费用、总费用。
%
%  环境：MATLAB R2025a（仅使用基础函数，不依赖统计工具箱）
%  依赖函数：load_data / anova_manual / save_F_result
%  运行方式：在 MATLAB 命令行直接执行  main_F_test

clc; clear; close all;

%% ---------- 0) 定位工作目录（避免绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

%% ---------- 1) 读取数据 ----------
data = load_data();

%% ---------- 2) 变量清单（A 类分类变量 16 个 + B 类连续变量 3 个） ----------
nA = 16;   % A 类（分类变量）个数
varList = {
    % ===== A 类：分类变量 =====
    '性别'
    '是否为老年人'
    '是否有伴侣'
    '是否有家属'
    '是否开通电话服务'
    '是否开通多条线路'
    '互联网服务类型'
    '是否开通在线安全'
    '是否开通在线备份'
    '是否开通设备保护'
    '是否开通技术支持'
    '是否开通电视流媒体'
    '是否开通电影流媒体'
    '合同类型'
    '是否使用电子账单'
    '支付方式'
    % ===== B 类：连续变量 =====
    '在网时长（月）'
    '月费用'
    '总费用'
    };

%% ---------- 3) 显著性水平 ----------
alpha = 0.05;

churnCol = data.('是否流失');   % 目标变量（0=未流失，1=流失）

%% ---------- 4) 逐变量手动单因素方差分析 ----------
nVars = numel(varList);

% 结果结构体数组（供 save_F_result 保存）
emptyRes = struct('varName', [], 'N_orig', [], 'N_missing', [], 'N_valid', [], ...
                  'n1', [], 'n2', [], 'N', [], ...
                  'mean1', [], 'mean2', [], 'grandMean', [], 'sd1', [], 'sd2', [], ...
                  'SST', [], 'SSA', [], 'SSE', [], 'sqErr', [], ...
                  'dfA', [], 'dfE', [], 'MSA', [], 'MSE', [], ...
                  'F', [], 'p', [], 'logp', [], 'pStr', [], 'sig', [], ...
                  'descTbl', [], 'sqTbl', [], 'anovaTbl', [], 'conclTbl', []);
resAll = repmat(emptyRes, nVars, 1);

% 汇总表数据
FAll   = zeros(nVars, 1);
d1All  = zeros(nVars, 1);
d2All  = zeros(nVars, 1);
pAll   = cell(nVars, 1);     % p 值科学计数法字符串
sigAll = cell(nVars, 1);

fprintf('========================================\n');
fprintf('  单因素方差分析（One-way ANOVA，α = %.2f）\n', alpha);
fprintf('========================================\n');
fprintf('%-12s %9s %9s %12s %6s %6s %18s %8s\n', ...
        '变量名称', '未流失均值', '流失均值', 'F统计量', 'df1', 'df2', 'p值', '显著性');
fprintf('%s\n', repmat('-', 1, 82));

for i = 1:nVars
    varName = varList{i};

    % 分组标题
    if i == 1
        fprintf('\n  【A 类：分类变量（16 个）】\n');
    elseif i == nA + 1
        fprintf('\n  【B 类：连续变量（3 个）】\n');
    end

    % 字段存在性检查
    if ~ismember(varName, data.Properties.VariableNames)
        error('[main_F_test] 数据中不存在字段 "%s"。', varName);
    end

    % 手动单因素方差分析
    x = data.(varName);
    res = anova_manual(x, churnCol, varName, alpha);
    resAll(i) = res;

    FAll(i) = res.F;
    d1All(i) = res.dfA;
    d2All(i) = res.dfE;
    pAll{i} = res.pStr;
    sigAll{i} = res.sig;

    % 控制台输出
    fprintf('%-12s %9.3f %9.3f %12.4f %6d %6d %18s %8s\n', ...
            varName, res.mean1, res.mean2, res.F, res.dfA, res.dfE, res.pStr, res.sig);
    if res.N_missing > 0
        fprintf('    [样本量] 原始=%d 缺失=%d 有效=%d（未流失=%d，流失=%d）\n', ...
                res.N_orig, res.N_missing, res.N_valid, res.n1, res.n2);
    end
end

%% ---------- 5) 汇总表 ----------
summaryTbl = table(varList, FAll, d1All, d2All, pAll, sigAll, ...
                   'VariableNames', {'变量名称', 'F值', 'df1', 'df2', 'p值', '是否显著'});

%% ---------- 6) 保存 Excel 结果 ----------
save_F_result(resAll, summaryTbl);

%% ---------- 7) 完成 ----------
fprintf('========================================\n');
fprintf('  连续变量单因素方差分析完成。\n');
fprintf('  共检验 %d 个变量（A 类分类变量 %d 个 + B 类连续变量 %d 个），\n', ...
        nVars, nA, nVars - nA);
fprintf('  其中显著（p < 0.05）%d 个，不显著 %d 个。\n', ...
        sum(strcmp(sigAll, '显著')), sum(strcmp(sigAll, '不显著')));
fprintf('  详细结果目录：%s\n', fullfile(pwd, '各类变量F检验详细结果'));
fprintf('  汇总总表：%s\n', fullfile(pwd, 'F检验总表.xlsx'));
fprintf('========================================\n');
