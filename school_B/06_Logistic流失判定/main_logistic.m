%% main_logistic.m —— 电信客户流失分析：问题2 Logistic 流失概率判定模型
%  功能：读取 01_数据预处理/B_processed.csv，采用二分类 Logistic 回归
%        建立客户流失概率判定模型 P(Y=1|X) = 1/(1+exp(-z))。
%
%  目标变量：是否流失（Y=1 表示客户流失，Y=0 表示客户未流失）
%
%  输入变量（16 个，取第一问卡方检验显著变量与 F 检验显著变量的交集）：
%    分类变量（13 个，保持数值编码）：是否为老年人、是否有伴侣、是否有家属、
%      互联网服务类型、是否开通在线安全、是否开通在线备份、是否开通设备保护、
%      是否开通技术支持、是否开通电视流媒体、是否开通电影流媒体、合同类型、
%      是否使用电子账单、支付方式
%    连续变量（3 个，Z-score 标准化）：在网时长（月）、月费用、总费用
%  删除：总费用为空（NaN）的样本。
%
%  参数估计：最大似然估计 + 牛顿迭代法（IRLS），不调用 fitglm 等工具箱函数。
%  输出：
%    Logistic_beta.xlsx       变量 | β | 标准误 | z统计量 | p值 | 影响方向
%    Logistic方程.txt         log(P/(1-P)) = β0 + β1X1 + ... + β16X16
%    prediction_result.xlsx   测试集：客户编号 | 真实流失状态 | 预测概率P | 预测类别
%    model_evaluation.xlsx    混淆矩阵(TP/TN/FP/FN) + Accuracy/Precision/Recall/F1
%    ROC_curve.png            ROC 曲线（手动实现）及 AUC
%
%  环境：MATLAB R2025a（仅基础函数，不依赖统计/机器学习工具箱）
%  依赖函数：load_data / prepare_variables / logistic_newton /
%           evaluate_model / save_result
%  运行方式：MATLAB 命令行直接执行 main_logistic

clc; clear; close all;

%% ---------- 0) 定位工作目录（相对路径，不依赖绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

fprintf('======== 电信客户流失分析与挽留策略 —— 问题2：Logistic 流失判定模型 ========\n');

%% ---------- 1) 读取数据（删除总费用缺失样本） ----------
[data, origRow] = load_data();

%% ---------- 2) 变量准备：提取16个输入变量 + 标准化 + 划分数据集 ----------
[Xtr, Ytr, Xte, Yte, keepIdxTest, P] = prepare_variables(data, origRow);

%% ---------- 3) 牛顿迭代法求解 β（最大似然估计，标准化尺度） ----------
[betaStd, stats] = logistic_newton(Xtr, Ytr);

%% ---------- 4) 还原原始变量尺度 ----------
contPos = P.contIdx + 1;                          % 连续变量在设计矩阵中的列位置（16:18）
beta_orig = betaStd;                              % 分类变量未标准化，β 不变
beta_orig(contPos) = betaStd(contPos) ./ P.sigma(:);
beta0_orig = betaStd(1) - sum(betaStd(contPos) .* P.mu(:) ./ P.sigma(:));
betaFeatOrig = beta_orig(2:end);                  % 16 个变量的原始尺度 β

% 命令窗口打印还原后的判定方程
varNames = [{'截距β0'}; P.vars(:)];               % 17×1
fprintf('\n===== 还原实际判定方程（原始变量尺度） =====\n');
fprintf('log(P/(1-P)) = %+.6f', beta0_orig);
for i = 2:numel(varNames)
    fprintf('\n    %+.6f × %s', betaFeatOrig(i-1), varNames{i});
end
fprintf('\n（P 为客户流失概率，判定规则：P>=0.5 判为流失。）\n');

%% ---------- 5) 测试集预测：流失概率与类别（阈值 0.5） ----------
zTe = Xte * betaStd;                              % 测试集线性组合（标准化尺度）
pTest = zeros(size(zTe));                         % 数值稳定的 sigmoid
pos = zTe >= 0;
pTest(pos)  = 1 ./ (1 + exp(-zTe(pos)));
pTest(~pos) = exp(zTe(~pos)) ./ (1 + exp(zTe(~pos)));
predClass = double(pTest >= 0.5);

%% ---------- 6) 模型评价：混淆矩阵 / 指标 / ROC / AUC ----------
evaluate_model(Yte, pTest, pwd);

%% ---------- 7) 保存结果：β表 / 判定方程 / 预测结果 ----------
save_result(P.vars, betaStd, betaFeatOrig, beta0_orig, stats, ...
            keepIdxTest, Yte, pTest, predClass, pwd);

%% ---------- 8) 完成 ----------
fprintf('\n=====================================================\n');
fprintf('  Logistic流失判定模型建立完成。\n');
fprintf('  结果文件目录：%s\n', pwd);
fprintf('=====================================================\n');
