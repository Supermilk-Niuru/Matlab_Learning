%% main_vif.m —— 问题2 Logistic 回归模型解释变量多重共线性（VIF）检验
%  功能：对进入 Logistic 流失判定模型的 16 个解释变量做方差膨胀因子
%        （Variance Inflation Factor, VIF）多重共线性检验。
%        本程序只做检验，不重新建模、不修改任何原始数据。
%
%  目标变量：是否流失（不参与 VIF 计算）
%  解释变量（与 Logistic 模型完全一致的 16 个）：
%    1  是否为老年人        2  是否有伴侣           3  是否有家属
%    4  互联网服务类型      5  是否开通在线安全     6  是否开通在线备份
%    7  是否开通设备保护    8  是否开通技术支持     9  是否开通电视流媒体
%   10  是否开通电影流媒体  11 合同类型            12 是否使用电子账单
%   13  支付方式           14 在网时长（月）      15 月费用
%   16  总费用
%  数据：删除总费用缺失（NaN）的 11 行，与 Logistic 模型一致，剩余 7032 个样本。
%
%  VIF 计算原理（矩阵最小二乘，不调用统计工具箱）：
%     对第 i 个变量 Xi，以其为因变量、其余 15 个变量为自变量做回归：
%       X_design = [ones, X_other]；beta = X_design \ Xi；
%       Xi_hat = X_design * beta；
%       SSE = sum((Xi-Xi_hat).^2)；SST = sum((Xi-mean(Xi)).^2)；
%       R_i^2 = 1 - SSE/SST；VIF_i = 1/(1-R_i^2)
%  判断标准：
%     VIF < 5      无明显共线性
%     5 ≤ VIF < 10 轻微共线性（注意）
%     VIF ≥ 10     严重共线性
%
%  输出（保存在本文件所在目录 06_Logistic流失判定/）：
%    VIF检验结果.xlsx   Sheet1 VIF总表；Sheet2 说明
%    VIF柱状图.png      VIF 柱状图（红色虚线 VIF=5，黑色虚线 VIF=10）
%
%  环境：MATLAB R2025a（仅基础函数，不依赖统计/机器学习工具箱）
%  运行方式：MATLAB 命令行直接执行 main_vif

clc; clear; close all;

%% ---------- 0) 定位工作目录（所有路径由 pwd 动态获取） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                        % 切换到脚本所在目录（06_Logistic流失判定）
end
outDir   = pwd;                           % 输出目录 = 06_Logistic流失判定
dataFile = fullfile(pwd, '..', '01_数据预处理', 'B_processed.csv');

fprintf('======== 问题2 Logistic 模型解释变量 VIF 多重共线性检验 ========\n');

%% ---------- 1) 读取数据并删除总费用缺失样本（与 Logistic 一致） ----------
if ~isfile(dataFile)
    error('[main_vif] 未找到数据文件：%s', dataFile);
end
data = readtable(dataFile, 'VariableNamingRule', 'preserve');

% 目标变量（仅读取，不参与 VIF 计算）
Y = data.('是否流失');

% 16 个解释变量（与 Logistic 模型完全一致）
vars = {'是否为老年人'; '是否有伴侣'; '是否有家属'; '互联网服务类型'; ...
        '是否开通在线安全'; '是否开通在线备份'; '是否开通设备保护'; ...
        '是否开通技术支持'; '是否开通电视流媒体'; '是否开通电影流媒体'; ...
        '合同类型'; '是否使用电子账单'; '支付方式'; ...
        '在网时长（月）'; '月费用'; '总费用'};
n = numel(vars);

% 删除总费用缺失行（11 行，在网时长为 0 的新客户），保持 7032 样本
bad = isnan(data.('总费用'));
data = data(~bad, :);
X = table2array(data(:, vars));           % 16 个解释变量矩阵
N = size(X, 1);
fprintf('删除总费用缺失样本 %d 行，有效样本 %d 行（与 Logistic 模型一致）。\n', sum(bad), N);

%% ---------- 2) 逐变量计算 R² 与 VIF（矩阵最小二乘） ----------
r2v = zeros(n, 1);
vif = zeros(n, 1);
for i = 1:n
    Xi     = X(:, i);                     % 第 i 个变量作为因变量
    others = setdiff(1:n, i);             % 其余 15 个变量的列索引
    X_other  = X(:, others);              % 其余 15 个变量作为自变量
    X_design = [ones(N, 1), X_other];     % 加入截距项

    beta = X_design \ Xi;                 % 最小二乘回归系数
    Xi_hat = X_design * beta;             % 预测值

    SSE = sum((Xi - Xi_hat).^2);          % 残差平方和
    SST = sum((Xi - mean(Xi)).^2);        % 总平方和

    R2 = 1 - SSE / SST;                   % 决定系数 R²
    if R2 >= 1                            % 防御：完全共线时 R²→1，VIF→Inf
        R2 = 1 - eps;
    end
    r2v(i) = R2;
    vif(i) = 1 / (1 - R2);                % VIF = 1/(1-R²)
end

%% ---------- 3) 共线性判断 ----------
judge = cell(n, 1);
for i = 1:n
    if     vif(i) < 5,        judge{i} = '无明显共线性';
    elseif vif(i) < 10,       judge{i} = '轻微共线性';
    else,                     judge{i} = '严重共线性';
    end
end

%% ---------- 4) 控制台输出 ----------
fprintf('\n%-12s %10s %8s    %s\n', '变量', 'R²', 'VIF', '判断');
fprintf('%s\n', repmat('-', 1, 52));
for i = 1:n
    fprintf('%-12s %10.4f %8.2f    %s\n', vars{i}, r2v(i), vif(i), judge{i});
end
fprintf('%s\n', repmat('-', 1, 48));
fprintf('VIF≥5 变量数：%d，其中 VIF≥10（严重共线性）变量数：%d。\n', ...
    sum(vif >= 5), sum(vif >= 10));

%% ---------- 5) 保存 Excel：VIF检验结果.xlsx ----------
% Sheet1 VIF总表
vifTbl = table(vars, r2v, vif, judge, ...
    'VariableNames', {'变量名称', 'R²', 'VIF', '判断结果'});
xlsFile = fullfile(outDir, 'VIF检验结果.xlsx');
if isfile(xlsFile); delete(xlsFile); end
writetable(vifTbl, xlsFile, 'Sheet', 'VIF总表', 'WriteMode', 'overwritesheet');

% Sheet2 说明
notes = {
    'VIF 多重共线性检验说明'
    ''
    '一、VIF 公式：'
    '    VIF_i = 1 / (1 - R_i^2)'
    '    其中 R_i^2 为第 i 个变量对其余解释变量（含截距）回归的决定系数。'
    ''
    '二、判断标准：'
    '    VIF < 5        无明显共线性'
    '    5 ≤ VIF < 10   注意共线性（轻微）'
    '    VIF ≥ 10       严重共线性'
    ''
    '三、说明：'
    '    检验对象为进入 Logistic 流失判定模型的 16 个解释变量；'
    '    目标变量"是否流失"不参与 VIF 计算；'
    '    数据删除总费用缺失 11 行，有效样本 7032 行，与 Logistic 模型一致；'
    '    程序未修改原始数据 B_processed.csv。'
    };
notesTbl = table(notes, 'VariableNames', {'说明内容'});
writetable(notesTbl, xlsFile, 'Sheet', '说明', 'WriteMode', 'overwritesheet');

fprintf('\n已保存：%s\n', xlsFile);

%% ---------- 6) 绘制 VIF 柱状图：VIF柱状图.png ----------
figure('Color', 'w', 'Position', [120 120 980 760]);
bar(1:n, vif, 0.6, 'FaceColor', [0.35 0.62 0.85]);
hold on;
% 红色虚线：VIF=5（轻微共线性阈值）
plot([0 n+1], [5 5], '--r', 'LineWidth', 1.4);
% 黑色虚线：VIF=10（严重共线性阈值）
plot([0 n+1], [10 10], '--k', 'LineWidth', 1.4);
hold off;

xticks(1:n);                              % 横轴变量名称
xticklabels(vars);
xtickangle(45);                           % 变量名称自动旋转
xlim([0 n+1]);
ylim([0 max([vif(:); 12]) * 1.12]);
xlabel('变量名称');
ylabel('VIF 值');
title('Logistic 模型解释变量 VIF 多重共线性检验');
legend('VIF', 'VIF = 5（轻微共线性阈值）', 'VIF = 10（严重共线性阈值）', ...
    'Location', 'northeastoutside');
grid on; box on;

% 在柱顶标注 VIF 数值
for i = 1:n
    text(i, vif(i) + ylim * [0; 0.03], sprintf('%.2f', vif(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end

pngFile = fullfile(outDir, 'VIF柱状图.png');
saveas(gcf, pngFile);
% close(gcf);
fprintf('已保存：%s\n', pngFile);

%% ---------- 7) 完成 ----------
fprintf('\n=====================================================\n');
fprintf('  Logistic模型VIF多重共线性检验完成。\n');
fprintf('  结果文件目录：%s\n', outDir);
fprintf('=====================================================\n');
