%% ========================================================================
%  build_LMM_variables.m
%  线性混合效应模型(LMM)建模前的数据变量构造
%
%  输入 : clean_NIPT_data.xlsx 中的 [男胎清洗数据] 工作表
%  输出 : LMM_ready_data.xlsx（可直接供 fitlme 使用的表）
%
%  任务内容（只做变量构造，不做任何模型拟合）：
%    1. 读取男胎清洗数据
%    2. Y染色体浓度 Y_conc 的 Logit 变换（带 epsilon 截断防止 0/1 越界）
%         Y_logit = log(Y_adj/(1-Y_adj))
%         Y_adj   = max(min(Y_conc, 1-epsilon), epsilon),  epsilon = 1e-5
%    3. 孕周 GA_weeks 均值中心化 : GA_c = GA_weeks - mean(GA_weeks)
%    4. BMI 均值中心化          : BMI_c = BMI     - mean(BMI)
%    5. 构造二次项              : GA_c2 = GA_c.^2,  BMI_c2 = BMI_c.^2
%    6. 输出变量                : SubjectID, Y_conc, Y_logit, GA_weeks,
%                                 GA_c, GA_c2, BMI, BMI_c, BMI_c2
%    7. 描述信息                : Y_logit 均值/标准差、GA 均值、BMI 均值、
%                                 新变量相关矩阵
%    8. 保存                    : LMM_ready_data.xlsx
%
%  运行方式：matlab -batch "cd('/Users/supermilk/Desktop/Matlab_2025C'); build_LMM_variables"
%  ========================================================================

%% ---------- 第 0 节：参数设置 ----------
dataFile = 'clean_NIPT_data.xlsx';          % 输入文件
inSheet  = '男胎清洗数据';                   % 输入工作表
outFile  = 'LMM_ready_data.xlsx';           % 输出文件
epsilon  = 1e-5;                            % Logit 变换的截断常数

%% ---------- 第 1 节：读取男胎清洗数据 ----------
fprintf('%s\n', repmat('=', 1, 72));
fprintf('步骤1：读取男胎清洗数据\n');
fprintf('%s\n', repmat('=', 1, 72));

T = readtable(dataFile, 'Sheet', inSheet, ...
              'VariableNamingRule', 'preserve');
fprintf('读取成功：%d 行 × %d 列\n', height(T), width(T));
fprintf('列名：%s\n', strjoin(T.Properties.VariableNames, ', '));

% 关键变量存在性检查
needVars = {'SubjectID', 'Y_conc', 'GA_weeks', 'BMI'};
missVar  = needVars(~ismember(needVars, T.Properties.VariableNames));
if ~isempty(missVar)
    error('缺少必要变量：%s', strjoin(missVar, ', '));
end

%% ---------- 第 2 节：Y_conc 的 Logit 变换 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤2：Y_conc 的 Logit 变换（Y_logit = log(Y_adj/(1-Y_adj))）\n');
fprintf('%s\n', repmat('=', 1, 72));

Y_raw  = double(T.Y_conc);                  % 原始 Y 染色体浓度
Y_adj  = max(min(Y_raw, 1 - epsilon), epsilon);  % 截断到 [epsilon, 1-epsilon]
Y_logit = log(Y_adj ./ (1 - Y_adj));        % Logit 变换

% 检查变换是否引入 NaN/Inf（理论上不会，防御性检查）
nBad = sum(~isfinite(Y_logit));
if nBad > 0
    warning('有 %d 个 Y_logit 非有限值（NaN/Inf）', nBad);
end
fprintf('Y_conc 范围 [%.4f, %.4f] -> Y_logit 范围 [%.4f, %.4f]\n', ...
        min(Y_raw), max(Y_raw), min(Y_logit), max(Y_logit));

%% ---------- 第 3 节：孕周均值中心化 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤3：孕周均值中心化 GA_c = GA_weeks - mean(GA_weeks)\n');
fprintf('%s\n', repmat('=', 1, 72));

GA_weeks = double(T.GA_weeks);
GA_mean  = mean(GA_weeks);                  % 中心化基准（均值）
GA_c     = GA_weeks - GA_mean;
fprintf('GA 均值 = %.6f 周，GA_c 范围 [%.6f, %.6f]\n', ...
        GA_mean, min(GA_c), max(GA_c));

%% ---------- 第 4 节：BMI 均值中心化 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤4：BMI 均值中心化 BMI_c = BMI - mean(BMI)\n');
fprintf('%s\n', repmat('=', 1, 72));

BMI     = double(T.BMI);
BMI_mean = mean(BMI);                       % 中心化基准（均值）
BMI_c   = BMI - BMI_mean;
fprintf('BMI 均值 = %.6f，BMI_c 范围 [%.6f, %.6f]\n', ...
        BMI_mean, min(BMI_c), max(BMI_c));

%% ---------- 第 5 节：构造二次项 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤5：构造二次项 GA_c2 = GA_c.^2, BMI_c2 = BMI_c.^2\n');
fprintf('%s\n', repmat('=', 1, 72));

GA_c2 = GA_c .^ 2;
BMI_c2 = BMI_c .^ 2;
fprintf('GA_c2 范围 [%.6f, %.6f]，BMI_c2 范围 [%.6f, %.6f]\n', ...
        min(GA_c2), max(GA_c2), min(BMI_c2), max(BMI_c2));

%% ---------- 第 6 节：组装输出表 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤6：组装输出表（table 结构）\n');
fprintf('%s\n', repmat('=', 1, 72));

LMM = table(T.SubjectID, Y_raw, Y_logit, GA_weeks, GA_c, GA_c2, ...
            BMI, BMI_c, BMI_c2, ...
            'VariableNames', {'SubjectID', 'Y_conc', 'Y_logit', ...
                              'GA_weeks', 'GA_c', 'GA_c2', ...
                              'BMI', 'BMI_c', 'BMI_c2'});

fprintf('输出表：%d 行 × %d 列\n', height(LMM), width(LMM));
fprintf('变量：%s\n', strjoin(LMM.Properties.VariableNames, ', '));

%% ---------- 第 7 节：输出描述信息 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤7：描述信息\n');
fprintf('%s\n', repmat('=', 1, 72));

fprintf('  Y_logit 均值 = %.6f，标准差 = %.6f\n', ...
        mean(Y_logit), std(Y_logit));
fprintf('  GA 均值      = %.6f\n', GA_mean);
fprintf('  BMI 均值     = %.6f\n', BMI_mean);

% 新变量相关矩阵（数值变量）
fprintf('\n新变量相关矩阵（Y_logit, GA_c, GA_c2, BMI_c, BMI_c2）：\n');
corrVars = {'Y_logit', 'GA_c', 'GA_c2', 'BMI_c', 'BMI_c2'};
R = corrcoef(LMM{:, corrVars});
fprintf('  变量         ');
for k = 1:numel(corrVars)
    fprintf('%10s ', corrVars{k});
end
fprintf('\n');
for i = 1:numel(corrVars)
    fprintf('  %-10s ', corrVars{i});
    for j = 1:numel(corrVars)
        fprintf('%10.4f ', R(i, j));
    end
    fprintf('\n');
end

%% ---------- 第 8 节：保存 ----------
fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('步骤8：保存 -> %s\n', outFile);
fprintf('%s\n', repmat('=', 1, 72));

% 先删除旧文件，避免 writetable 残留多余工作表
if exist(outFile, 'file')
    delete(outFile);
end
writetable(LMM, outFile, 'Sheet', 'LMM建模数据');
fprintf('已保存：%s（%d 行 × %d 列）\n', outFile, height(LMM), width(LMM));
fprintf('  Y_logit = log(max(min(Y_conc, 1-%.1e), %.1e) ./ ...)\n', ...
        epsilon, epsilon);
fprintf('\n全部完成。\n');
