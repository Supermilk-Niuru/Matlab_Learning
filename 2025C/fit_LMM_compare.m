%% ========================================================================
%  fit_LMM_compare.m
%  2025年数学建模C题问题1 —— 模型比较与拟合评价
%
%  三个模型（固定效应结构完全相同，仅随机效应结构不同）：
%    M1 : 普通线性模型    Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2
%    M2 : 随机截距LMM     Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 | SubjectID)
%    M3 : 随机截距+斜率   Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 + GA_c | SubjectID)
%    M3 为当前确定的最终模型。
%
%  评价要点：
%    (1) LMM 用 REML 拟合最终模型；为嵌套模型比较，M2/M3 另用 ML 拟合；
%    (2) 原始 Y_conc 尺度上的 R² 与 RMSE：必须先用逆 Logit 变换把预测值
%        还原到 Y 浓度原始尺度，再计算（不能直接在 Y_logit 上算）；
%    (3) LMM 分 marginal（仅固定效应）与 conditional（固定效应+BLUP）
%        两种预测分别计算；
%    (4) ICC 基于随机截距方差与残差方差；
%    (5) 嵌套模型似然比检验：M1 vs M2、M2 vs M3（用 ML 拟合）。
%
%  输出 :
%    model_comparison_results.xlsx（模型比较表 + 似然比检验表）
%    M1_model.mat / M2_model.mat / M3_model.mat
%    model_comparison_workspace.mat（完整工作区）
%
%  约束：不修改数据、不删除异常值、不加入年龄/身高/体重等其他变量，
%        不做问题2/3/4的分析，仅做模型比较与拟合评价。
%
%  运行方式：matlab -batch "cd('/Users/supermilk/Desktop/Matlab_2025C'); fit_LMM_compare"
%  ========================================================================

%% ---------- 第 0 节：参数设置 ----------
dataFile = 'LMM_ready_data.xlsx';   % 输入文件
inSheet  = 'LMM建模数据';            % 输入工作表（男胎数据）
outFile  = 'model_comparison_results.xlsx';

% 各模型公式
fmlM1 = 'Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2';                       % 普通线性模型
fmlM2 = 'Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 | SubjectID)';     % 随机截距
fmlM3 = 'Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 + GA_c | SubjectID)'; % 随机截距+斜率(最终)

%% ---------- 第 1 节：读取数据 ----------
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤1：读取男胎建模数据\n');
fprintf('%s\n', repmat('=', 1, 72));

LMM = readtable(dataFile, 'Sheet', inSheet, 'VariableNamingRule', 'preserve');
LMM.SubjectID = string(LMM.SubjectID);   % 分组变量转 string，供 fitlme 识别
fprintf('读取成功：%d 行 × %d 列，孕妇数=%d\n', ...
        height(LMM), width(LMM), numel(unique(LMM.SubjectID)));

% 原始 Y 浓度（所有 R²/RMSE 都在此尺度上计算）
Y_conc = double(LMM.Y_conc);
n = numel(Y_conc);
muY   = mean(Y_conc);
SST   = sum((Y_conc - muY).^2);   % 总平方和（原始尺度分母）

%% ---------- 第 2 节：拟合三个模型 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤2：拟合 M1 / M2 / M3\n');
fprintf('%s\n', repmat('=', 1, 72));

% ---- M1 : 普通线性模型（OLS，忽略重复测量结构）----
M1 = fitlm(LMM, fmlM1);
fprintf('M1 拟合成功（fitlm, OLS）\n');

% ---- M2 : 随机截距 LMM（REML 最终 + ML 用于比较）----
M2    = fitlme(LMM, fmlM2, 'FitMethod', 'REML');
M2_ML = fitlme(LMM, fmlM2, 'FitMethod', 'ML');
fprintf('M2 拟合成功（fitlme, REML 与 ML）\n');

% ---- M3 : 随机截距+随机斜率 LMM（REML 最终 + ML 用于比较）----
M3    = fitlme(LMM, fmlM3, 'FitMethod', 'REML');
M3_ML = fitlme(LMM, fmlM3, 'FitMethod', 'ML');
fprintf('M3 拟合成功（fitlme, REML 与 ML）\n');

%% ---------- 第 3 节：各模型的 LogLikelihood / AIC / BIC ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤3：模型信息量准则\n');
fprintf('%s\n', repmat('=', 1, 72));

% M1 为 OLS（等价 ML）；M2/M3 同时给出 REML 与 ML
fprintf('  %-22s %-6s %12s %12s %12s\n', '模型', '方法', 'LogLikelihood', 'AIC', 'BIC');
fprintf('  %s\n', repmat('-', 1, 60));
fprintf('  %-22s %-6s %12.4f %12.4f %12.4f\n', 'M1(OLS)', '-', ...
        M1.LogLikelihood, M1.ModelCriterion.AIC, M1.ModelCriterion.BIC);
fprintf('  %-22s %-6s %12.4f %12.4f %12.4f\n', 'M2(LMM)', 'REML', ...
        M2.LogLikelihood, M2.ModelCriterion.AIC, M2.ModelCriterion.BIC);
fprintf('  %-22s %-6s %12.4f %12.4f %12.4f\n', 'M2(LMM)', 'ML', ...
        M2_ML.LogLikelihood, M2_ML.ModelCriterion.AIC, M2_ML.ModelCriterion.BIC);
fprintf('  %-22s %-6s %12.4f %12.4f %12.4f\n', 'M3(LMM)', 'REML', ...
        M3.LogLikelihood, M3.ModelCriterion.AIC, M3.ModelCriterion.BIC);
fprintf('  %-22s %-6s %12.4f %12.4f %12.4f\n', 'M3(LMM)', 'ML', ...
        M3_ML.LogLikelihood, M3_ML.ModelCriterion.AIC, M3_ML.ModelCriterion.BIC);
fprintf('\n说明：模型间比较一律使用 ML 拟合的 LL/AIC/BIC（M1 为 OLS 等价 ML），\n');
fprintf('      不能拿 REML 的 AIC 去比较固定效应结构不同的模型。\n');

% 提取比较用（ML 基准）的值
LL1 = M1.LogLikelihood;            AIC1 = M1.ModelCriterion.AIC;            BIC1 = M1.ModelCriterion.BIC;
LL2 = M2_ML.LogLikelihood;         AIC2 = M2_ML.ModelCriterion.AIC;         BIC2 = M2_ML.ModelCriterion.BIC;
LL3 = M3_ML.LogLikelihood;         AIC3 = M3_ML.ModelCriterion.AIC;         BIC3 = M3_ML.ModelCriterion.BIC;

%% ---------- 第 4 节：原始 Y 浓度尺度上的拟合评价 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤4：原始 Y 浓度尺度的 R² 与 RMSE（逆 Logit 后计算）\n');
fprintf('%s\n', repmat('=', 1, 72));

% 逆 Logit 变换：Y_pred = exp(lp) ./ (1 + exp(lp))
invLogit = @(lp) exp(lp) ./ (1 + exp(lp));

% ---- M1 : 无随机效应，marginal 与 conditional 相同 ----
lpM1        = M1.Fitted;                      % Y_logit 尺度预测
predM1      = invLogit(lpM1);                 % 还原到原始 Y 浓度
[RMSE_M1, R2_M1] = fit_metrics(Y_conc, predM1, SST);
fprintf('M1: RMSE=%.5f  R²=%.5f（原始Y浓度尺度）\n', RMSE_M1, R2_M1);

% ---- M2 : marginal（仅固定效应）与 conditional（固定+BLUP）----
lpM2_marg = predict(M2, 'Conditional', false);   % marginal 预测（logit 尺度）
lpM2_cond = predict(M2);                         % conditional 预测（含 BLUP）
predM2_marg = invLogit(lpM2_marg);
predM2_cond = invLogit(lpM2_cond);
[RMSE_M2_marg, R2_M2_marg] = fit_metrics(Y_conc, predM2_marg, SST);
[RMSE_M2_cond, R2_M2_cond] = fit_metrics(Y_conc, predM2_cond, SST);
fprintf('M2: marginal RMSE=%.5f R²=%.5f | conditional RMSE=%.5f R²=%.5f\n', ...
        RMSE_M2_marg, R2_M2_marg, RMSE_M2_cond, R2_M2_cond);

% ---- M3 : marginal 与 conditional ----
lpM3_marg = predict(M3, 'Conditional', false);
lpM3_cond = predict(M3);
predM3_marg = invLogit(lpM3_marg);
predM3_cond = invLogit(lpM3_cond);
[RMSE_M3_marg, R2_M3_marg] = fit_metrics(Y_conc, predM3_marg, SST);
[RMSE_M3_cond, R2_M3_cond] = fit_metrics(Y_conc, predM3_cond, SST);
fprintf('M3: marginal RMSE=%.5f R²=%.5f | conditional RMSE=%.5f R²=%.5f\n', ...
        RMSE_M3_marg, R2_M3_marg, RMSE_M3_cond, R2_M3_cond);

%% ---------- 第 5 节：ICC（组内相关系数）----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤5：组内相关系数 ICC\n');
fprintf('%s\n', repmat('=', 1, 72));

% ICC = sigma_subject^2 / (sigma_subject^2 + sigma_residual^2)
covM2 = covarianceParameters(M2);   covM2 = covM2{1};          % M2: 1×1 截距方差
covM3 = covarianceParameters(M3);   covM3 = covM3{1};          % M3: 2×2 [截距, 斜率]

varSubjM2 = covM2(1,1);   MSE_M2 = M2.MSE;                     % 残差方差
varSubjM3 = covM3(1,1);   MSE_M3 = M3.MSE;
varSlopeM3 = covM3(2,2);

ICC_M2 = varSubjM2 / (varSubjM2 + MSE_M2);
ICC_M3 = varSubjM3 / (varSubjM3 + MSE_M3);

fprintf('M2: 随机截距方差=%.6f, 残差方差=%.6f, ICC=%.6f\n', ...
        varSubjM2, MSE_M2, ICC_M2);
fprintf('M3: 随机截距方差=%.6f, 随机斜率方差=%.6f, 残差方差=%.6f, 基础ICC=%.6f\n', ...
        varSubjM3, varSlopeM3, MSE_M3, ICC_M3);
fprintf('\n注意：M3 存在随机孕周斜率，上述 ICC 是基于随机截距与残差方差的\n');
fprintf('      基础 ICC，而不是完整的随时间变化的条件相关系数（需考虑随机斜率贡献）。\n');

%% ---------- 第 6 节：模型比较表 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤6：模型比较表\n');
fprintf('%s\n', repmat('=', 1, 72));

% M1 无随机效应：ICC 与 conditional 列填 NaN
CompTbl = table({'M1'; 'M2'; 'M3'}, ...
    [LL1; LL2; LL3], ...
    [AIC1; AIC2; AIC3], ...
    [BIC1; BIC2; BIC3], ...
    [R2_M1; R2_M2_marg; R2_M3_marg], ...
    [RMSE_M1; RMSE_M2_marg; RMSE_M3_marg], ...
    [NaN; R2_M2_cond; R2_M3_cond], ...
    [NaN; RMSE_M2_cond; RMSE_M3_cond], ...
    [NaN; ICC_M2; ICC_M3], ...
    'VariableNames', {'Model', 'LogLikelihood', 'AIC', 'BIC', ...
                      'R2_marginal', 'RMSE_marginal', ...
                      'R2_conditional', 'RMSE_conditional', 'ICC'});

fprintf('%-8s %12s %12s %12s %12s %14s %14s %14s %10s\n', ...
    'Model', 'LogLikelihood', 'AIC', 'BIC', 'R2_marginal', ...
    'RMSE_marginal', 'R2_cond', 'RMSE_cond', 'ICC');
fprintf('%s\n', repmat('-', 1, 108));
for k = 1:height(CompTbl)
    fprintf('%-8s %12.4f %12.4f %12.4f %12.5f %14.5f %14s %14s %10s\n', ...
        CompTbl.Model{k}, CompTbl.LogLikelihood(k), CompTbl.AIC(k), CompTbl.BIC(k), ...
        CompTbl.R2_marginal(k), CompTbl.RMSE_marginal(k), ...
        fmt_num(CompTbl.R2_conditional(k)), fmt_num(CompTbl.RMSE_conditional(k)), ...
        fmt_num(CompTbl.ICC(k)));
end

%% ---------- 第 7 节：嵌套模型似然比检验 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤7：嵌套模型似然比检验（ML 拟合，LRT = 2*(LL_full - LL_reduced)）\n');
fprintf('%s\n', repmat('=', 1, 72));

% M1 vs M2 : 加入随机截距是否显著改善？（df = 1 个方差参数）
LRT_12 = 2 * (LL2 - LL1);   df_12 = 1;   p_12 = chi2cdf(LRT_12, df_12, 'upper');
fprintf('M1 vs M2 : LRT=%.4f, 自由度差=%d, p=%.4g\n', LRT_12, df_12, p_12);

% M2 vs M3 : 加入随机孕周斜率是否显著改善？（df = 2：斜率方差 + 协方差）
LRT_23 = 2 * (LL3 - LL2);   df_23 = 2;   p_23 = chi2cdf(LRT_23, df_23, 'upper');
fprintf('M2 vs M3 : LRT=%.4f, 自由度差=%d, p=%.4g\n', LRT_23, df_23, p_23);

% 结论
fprintf('\n结论：\n');
if p_12 < 0.05
    fprintf('  1. 加入随机截距显著改善模型（p=%.4g），重复测量结构不可忽略。\n', p_12);
else
    fprintf('  1. 加入随机截距未显著改善模型（p=%.4g）。\n', p_12);
end
if p_23 < 0.05
    fprintf('  2. 加入随机孕周斜率显著改善模型（p=%.4g）。\n', p_23);
else
    fprintf('  2. 加入随机孕周斜率未显著改善模型（p=%.4g）。\n', p_23);
end
fprintf('\n注：方差参数为 0 的零假设位于参数空间边界，上述 p 值偏保守（标准做法）。\n');

LRT_tbl = table({'M1 vs M2'; 'M2 vs M3'}, [LRT_12; LRT_23], [df_12; df_23], [p_12; p_23], ...
    'VariableNames', {'Comparison', 'LRT_statistic', 'df_diff', 'pValue'});

%% ---------- 第 8 节：保存 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤8：保存结果\n');
fprintf('%s\n', repmat('=', 1, 72));

% 8.1 模型比较结果 xlsx（两个工作表）
if exist(outFile, 'file'), delete(outFile); end
writetable(CompTbl, outFile, 'Sheet', '模型比较表');
writetable(LRT_tbl, outFile, 'Sheet', '似然比检验');
fprintf('已保存：%s（模型比较表 + 似然比检验）\n', outFile);

% 8.2 各模型对象
save('M1_model.mat', 'M1', 'fmlM1');
save('M2_model.mat', 'M2', 'fmlM2');
save('M3_model.mat', 'M3', 'fmlM3');
fprintf('已保存：M1_model.mat / M2_model.mat / M3_model.mat\n');

% 8.3 完整工作区
save('model_comparison_workspace.mat');
fprintf('已保存：model_comparison_workspace.mat（完整工作区）\n');

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('全部完成。\n');
fprintf('%s\n', repmat('=', 1, 72));

%% ==================== 局部函数 ====================

% 计算原始 Y 浓度尺度上的 RMSE 与 R²
function [rmse, R2] = fit_metrics(Y_conc, Y_pred, SST)
    SSE  = sum((Y_conc - Y_pred).^2);     % 残差平方和
    rmse = sqrt(mean((Y_conc - Y_pred).^2));  % RMSE
    R2   = 1 - SSE / SST;                 % 决定系数（可小于0）
end

% 格式化输出数值；NaN 显示为 'NaN'
function s = fmt_num(x)
    if isnan(x)
        s = 'NaN';
    else
        s = sprintf('%.5f', x);
    end
end
