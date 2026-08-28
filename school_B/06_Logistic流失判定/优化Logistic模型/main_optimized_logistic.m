%% main_optimized_logistic.m —— 问题2 Logistic 模型优化（剔除严重共线性变量）
%  功能：根据 VIF 多重共线性检验结果，删除 VIF>10 的 3 个严重共线性变量
%        （互联网服务类型、月费用、总费用），用剩余 13 个变量重新建立
%        Logistic 客户流失概率判定模型，并与原始模型在同一测试集上对比。
%  本程序不删除、不覆盖 06_Logistic流失判定/ 中任何已有文件
%  （原始模型文件、VIF 检验文件均保持不变），所有优化结果保存在本文件夹。
%
%  优化后解释变量（13 个）：
%    分类变量（12 个，保持数值编码）：是否为老年人、是否有伴侣、是否有家属、
%      是否开通在线安全、是否开通在线备份、是否开通设备保护、是否开通技术支持、
%      是否开通电视流媒体、是否开通电影流媒体、合同类型、是否使用电子账单、支付方式
%    连续变量（1 个，Z-score 标准化）：在网时长（月）
%  目标变量：是否流失（Y=1 流失，Y=0 未流失）
%  删除：总费用缺失（NaN）样本 11 行，有效样本 7032 行（与原始模型一致）。
%
%  参数估计：最大似然估计 + 牛顿迭代法（IRLS），不调用 fitglm 等工具箱函数。
%  数据划分：与原始 Logistic 模型完全一致（rng(2026)，70% 训练 / 30% 测试），
%     保证测试集与之前模型相同。
%
%  输出（保存在本文件夹 优化Logistic模型/）：
%    Optimized_Logistic_beta.xlsx   变量名称 | β标准化尺度 | 标准误 | z统计量 |
%                                   p值 | β原始尺度 | 影响方向
%    Optimized_Logistic方程.txt     log(P/(1-P)) = β0 + β1X1 + ... + β13X13
%    Optimized_model_evaluation.xlsx  混淆矩阵(TP/TN/FP/FN) + Accuracy/Precision/Recall/F1
%    Optimized_ROC_curve.png        ROC 曲线（手动实现）及 AUC
%    Model_comparison.xlsx          原始模型 vs 优化模型：变量数量与各指标对比
%
%  环境：MATLAB R2025a（仅基础函数，不依赖统计/机器学习工具箱）
%  依赖函数：load_opt_data / prepare_opt_variables / logistic_newton /
%           evaluate_opt_model / save_opt_result / compare_models
%  运行方式：MATLAB 命令行直接执行 main_optimized_logistic

clc; clear; close all;

%% ---------- 0) 定位工作目录（所有路径由 pwd 动态获取） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);                        % 切换到 06_Logistic流失判定/优化Logistic模型/
end
outDir = pwd;

fprintf('======== 问题2：Logistic 模型优化（剔除 VIF>10 严重共线性变量） ========\n');
fprintf('删除变量：互联网服务类型、月费用、总费用\n');

%% ---------- 1) 读取数据（删除总费用缺失样本，与原始模型一致） ----------
[data, origRow] = load_opt_data();

%% ---------- 2) 变量准备：13 个变量 + 标准化 + 划分数据集（同一测试集） ----------
[Xtr, Ytr, Xte, Yte, keepIdxTest, P] = prepare_opt_variables(data, origRow);
fprintf('最终保留变量数量：%d 个。\n', numel(P.vars));

%% ---------- 3) 牛顿迭代法求解 β（最大似然估计，标准化尺度） ----------
[betaStd, stats] = logistic_newton(Xtr, Ytr);

%% ---------- 4) 还原原始变量尺度 ----------
contPos = P.contIdx + 1;                          % 连续变量在设计矩阵中的列位置（14）
beta_orig = betaStd;                              % 分类变量未标准化，β 不变
beta_orig(contPos) = betaStd(contPos) ./ P.sigma(:);
beta0_orig = betaStd(1) - sum(betaStd(contPos) .* P.mu(:) ./ P.sigma(:));
betaFeatOrig = beta_orig(2:end);                  % 13 个变量的原始尺度 β

% 命令窗口打印还原后的判定方程
varNames = [{'截距β0'}; P.vars(:)];               % 14×1
fprintf('\n===== 还原实际判定方程（原始变量尺度） =====\n');
fprintf('log(P/(1-P)) = %+.6f', beta0_orig);
for i = 2:numel(varNames)
    fprintf('\n    %+.6f × %s', betaFeatOrig(i-1), varNames{i});
end
fprintf('\n（P 为客户流失概率，判定规则：P>=0.5 判为流失。）\n');

%% ---------- 5) 测试集预测：流失概率与类别（阈值 0.5，同一测试集） ----------
zTe = Xte * betaStd;                              % 测试集线性组合（标准化尺度）
pTest = zeros(size(zTe));                         % 数值稳定的 sigmoid
pos = zTe >= 0;
pTest(pos)  = 1 ./ (1 + exp(-zTe(pos)));
pTest(~pos) = exp(zTe(~pos)) ./ (1 + exp(zTe(~pos)));
predClass = double(pTest >= 0.5);

%% ---------- 6) 模型评价：混淆矩阵 / 指标 / ROC / AUC ----------
optM = evaluate_opt_model(Yte, pTest, outDir);

%% ---------- 7) 保存结果：β表 / 数学方程 ----------
save_opt_result(P.vars, betaStd, betaFeatOrig, beta0_orig, stats, outDir);

%% ---------- 8) 模型对比：原始模型 vs 优化模型 ----------
compare_models(optM, outDir);

%% ---------- 9) 完成 ----------
fprintf('\n=====================================================\n');
fprintf('  优化Logistic模型建立完成。\n');
fprintf('  删除变量：互联网服务类型、月费用、总费用\n');
fprintf('  最终保留变量数量：13 个。\n');
fprintf('  结果文件目录：%s\n', outDir);
fprintf('=====================================================\n');
