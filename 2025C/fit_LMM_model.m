%% ========================================================================
%  fit_LMM_model.m
%  2025年数学建模C题问题1 —— 线性混合效应模型(LMM)求解
%
%  输入 : LMM_ready_data.xlsx 中的 [LMM建模数据] 工作表（男胎数据）
%  模型 :
%     Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 + GA_c | SubjectID)
%    - 因变量   : Y_logit（Y染色体浓度的 Logit 变换值）
%    - 固定效应 : GA_c, GA_c2, BMI_c, BMI_c2（均已中心化/二次构造）
%    - 随机效应 : 随机截距 + 随机孕周斜率（按孕妇分组）
%    - 估计方法 : 限制最大似然(REML)
%
%  输出 :
%    (1) 模型公式
%    (2) 固定效应估计 : 参数估计值/标准误/t值/p值/95%CI
%    (3) 随机效应     : 随机截距方差/随机斜率方差/协方差
%    (4) 模型评价     : AIC/BIC/LogLikelihood
%    (5) 保存模型     : LMM_model.mat
%    (6) 每个孕妇的 BLUP 随机效应估计(randomEffects) -> BLUP_results.xlsx
%
%  说明 : 不修改数据、不删除异常值、不加入其他变量，仅拟合指定模型。
%
%  运行方式：matlab -batch "cd('/Users/supermilk/Desktop/Matlab_2025C'); fit_LMM_model"
%  ========================================================================

%% ---------- 第 0 节：参数设置 ----------
dataFile  = 'LMM_ready_data.xlsx';   % 输入文件
inSheet   = 'LMM建模数据';            % 输入工作表（男胎数据）
matFile   = 'LMM_model.mat';         % 模型保存文件
blupFile  = 'BLUP_results.xlsx';     % BLUP 输出文件

% 模型公式（字符串，供 fitlme 解析）
modelFormula = 'Y_logit ~ GA_c + GA_c2 + BMI_c + BMI_c2 + (1 + GA_c | SubjectID)';

%% ---------- 第 1 节：读取数据 ----------
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤1：读取男胎建模数据\n');
fprintf('%s\n', repmat('=', 1, 72));

LMM = readtable(dataFile, 'Sheet', inSheet, ...
                'VariableNamingRule', 'preserve');
fprintf('读取成功：%d 行 × %d 列\n', height(LMM), width(LMM));
fprintf('变量：%s\n', strjoin(LMM.Properties.VariableNames, ', '));

% 模型所需变量存在性检查
needVars = {'SubjectID', 'Y_logit', 'GA_c', 'GA_c2', 'BMI_c', 'BMI_c2'};
missVar  = needVars(~ismember(needVars, LMM.Properties.VariableNames));
if ~isempty(missVar)
    error('缺少模型变量：%s', strjoin(missVar, ', '));
end

% 分组变量转为 string 类型，保证 fitlme 正常识别（不改动数据值）
LMM.SubjectID = string(LMM.SubjectID);
fprintf('孕妇（分组）数：%d，总观测数：%d\n', ...
        numel(unique(LMM.SubjectID)), height(LMM));

%% ---------- 第 2 节：拟合线性混合效应模型（REML） ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤2：拟合 LMM（REML 估计）\n');
fprintf('%s\n', repmat('=', 1, 72));

% 'FitMethod','REML' 使用限制最大似然估计
lme = fitlme(LMM, modelFormula, 'FitMethod', 'REML');
fprintf('模型拟合成功。\n');

%% ---------- 第 3 节：输出（1）模型公式 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤3：模型公式\n');
fprintf('%s\n', repmat('=', 1, 72));

fprintf('  %s\n', modelFormula);
fprintf('  固定效应项 : %s\n', strjoin(lme.CoefficientNames', ' + '));
% 从模型公式中解析分组变量名（如 '(1 + GA_c | SubjectID)' -> 'SubjectID'）
gtok = regexp(modelFormula, '\|\s*(\w+)\s*\)', 'tokens', 'once');
grpVar = gtok{1};
fprintf('  随机效应分组变量 : %s\n', grpVar);
fprintf('  估计方法 : %s\n', lme.FitMethod);

%% ---------- 第 4 节：输出（2）固定效应估计结果 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤4：固定效应估计结果\n');
fprintf('%s\n', repmat('=', 1, 72));

fixTab = lme.Coefficients;   % 列: Name Estimate SE tStat DF pValue Lower Upper
fprintf('%-14s %12s %10s %10s %8s %12s %12s %12s\n', ...
        '变量', '估计值', '标准误', 't值', '自由度', 'p值', '95%CI下', '95%CI上');
fprintf('%s\n', repmat('-', 1, 90));
for k = 1:height(fixTab)
    fprintf('%-14s %12.5f %10.5f %10.3f %8d %12.4g %12.5f %12.5f\n', ...
            fixTab.Name{k}, fixTab.Estimate(k), fixTab.SE(k), ...
            fixTab.tStat(k), fixTab.DF(k), fixTab.pValue(k), ...
            fixTab.Lower(k), fixTab.Upper(k));
end

%% ---------- 第 5 节：输出（3）随机效应结果 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤5：随机效应结果（随机截距 + 随机孕周斜率）\n');
fprintf('%s\n', repmat('=', 1, 72));

% covarianceParameters(lme) 返回 cell，其中第1个元素即为随机效应的
% 协方差矩阵（行/列顺序：截距, GA_c 斜率），可直接读取方差与协方差
covMtx  = covarianceParameters(lme);
covMtx  = covMtx{1};
varInt  = covMtx(1, 1);     % 随机截距方差
varSlp  = covMtx(2, 2);     % 随机斜率方差
covIntS = covMtx(1, 2);     % 截距-斜率协方差

fprintf('  随机效应协方差矩阵（截距, 斜率）：\n');
fprintf('      %.6f    %.6f\n', varInt, covIntS);
fprintf('      %.6f    %.6f\n', covIntS, varSlp);
fprintf('\n  随机截距方差          = %.6f (SD=%.4f)\n', varInt, sqrt(varInt));
fprintf('  随机斜率(GA_c)方差    = %.6f (SD=%.4f)\n', varSlp, sqrt(varSlp));
fprintf('  截距-斜率协方差       = %.6f\n', covIntS);
if varInt > 0 && varSlp > 0
    fprintf('  截距-斜率相关系数    = %.6f\n', covIntS / (sqrt(varInt)*sqrt(varSlp)));
end
fprintf('  残差方差(MSE)         = %.6f (SD=%.4f)\n', lme.MSE, sqrt(lme.MSE));

%% ---------- 第 6 节：输出（4）模型评价 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤6：模型评价指标\n');
fprintf('%s\n', repmat('=', 1, 72));

mc = lme.ModelCriterion;    % 列: AIC BIC LogLikelihood Deviance
fprintf('  AIC            = %.4f\n', mc.AIC);
fprintf('  BIC            = %.4f\n', mc.BIC);
fprintf('  LogLikelihood  = %.4f\n', lme.LogLikelihood);
fprintf('  Deviance       = %.4f\n', lme.LogLikelihood * (-2));

%% ---------- 第 7 节：保存模型 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤7：保存模型 -> %s\n', matFile);
fprintf('%s\n', repmat('=', 1, 72));

save(matFile, 'lme', 'modelFormula', 'LMM');
fprintf('已保存：%s（含 lme 对象、公式、建模数据）\n', matFile);

%% ---------- 第 8 节：输出并保存每个孕妇的 BLUP 随机效应 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤8：每个孕妇的 BLUP 随机效应估计 -> %s\n', blupFile);
fprintf('%s\n', repmat('=', 1, 72));

[blup, blupNames, blupStats] = randomEffects(lme);
% blupNames 表: Group Level Name；blup 为对应 BLUP 估计
lvl = string(blupNames.Level);
nm  = string(blupNames.Name);
iInt = nm == '(Intercept)';
iSlp = nm == 'GA_c';

subjID  = lvl(iInt);                % 按分组水平顺序的孕妇编号
blupInt = blup(iInt);               % 随机截距 BLUP
blupSlp = blup(iSlp);               % 随机斜率 BLUP
% blupStats 提供各 BLUP 的标准误（R2025a 中列名为 SEPred，不是 SE）
seInt   = blupStats.SEPred(iInt);
seSlp   = blupStats.SEPred(iSlp);

BLUP = table(subjID, blupInt, blupSlp, seInt, seSlp, ...
    'VariableNames', {'SubjectID', 'BLUP_intercept', 'BLUP_slope', ...
                      'SE_intercept', 'SE_slope'});
fprintf('BLUP 行数：%d（= 孕妇数）\n', height(BLUP));
fprintf('随机截距 BLUP：均值 %.6f，范围 [%.6f, %.6f]\n', ...
        mean(blupInt), min(blupInt), max(blupInt));
fprintf('随机斜率 BLUP：均值 %.6f，范围 [%.6f, %.6f]\n', ...
        mean(blupSlp), min(blupSlp), max(blupSlp));

% 预览前 5 行
fprintf('\n前 5 位孕妇的 BLUP：\n');
for k = 1:min(5, height(BLUP))
    fprintf('  %-8s  截距=%8.5f(SE=%.5f)  斜率=%8.5f(SE=%.5f)\n', ...
            BLUP.SubjectID(k), BLUP.BLUP_intercept(k), BLUP.SE_intercept(k), ...
            BLUP.BLUP_slope(k), BLUP.SE_slope(k));
end

% 保存
if exist(blupFile, 'file')
    delete(blupFile);
end
writetable(BLUP, blupFile, 'Sheet', 'BLUP随机效应');
fprintf('\n已保存：%s（%d 行 × %d 列）\n', blupFile, height(BLUP), width(BLUP));

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('全部完成。\n');
fprintf('%s\n', repmat('=', 1, 72));
