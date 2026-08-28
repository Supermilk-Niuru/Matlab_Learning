function save_opt_result(vars, betaStdAll, betaFeatOrig, beta0Orig, stats, outDir)
% SAVE_OPT_RESULT 保存优化模型结果：β系数表 / Logistic 数学方程
%
%   输入：
%     vars          —— 输入变量名称（13×1 元胞）
%     betaStdAll    —— 标准化尺度 β（14×1，β(1)=截距 β0，含截距）
%     betaFeatOrig  —— 原始尺度 β（13×1，不含截距）
%     beta0Orig     —— 原始尺度截距 β0（标量）
%     stats         —— 结构体：se / z / p / iter / err（标准化尺度）
%     outDir        —— 输出文件夹
%
%   输出文件：
%     Optimized_Logistic_beta.xlsx  变量名称 | β标准化尺度 | 标准误 | z统计量 |
%                                   p值 | β原始尺度 | 影响方向
%     Optimized_Logistic方程.txt    log(P/(1-P)) = β0 + β1X1 + ... + β13X13

%% ---------- 1) 组装 β 系数表并保存 Optimized_Logistic_beta.xlsx ----------
varNames = [{'截距β0'}; vars(:)];                 % 14×1
betaOrigAll = [beta0Orig; betaFeatOrig];          % 原始尺度 β（含截距）

% 影响方向：β>0 升高流失风险，β<0 降低流失风险
dirSign = cell(numel(varNames), 1);
for i = 1:numel(varNames)
    if     betaOrigAll(i) >  1e-12, dirSign{i} = '正(升高流失)';
    elseif betaOrigAll(i) < -1e-12, dirSign{i} = '负(降低流失)';
    else                          , dirSign{i} = '≈0';
    end
end

betaTbl = table(varNames, betaStdAll, stats.se, stats.z, stats.p, betaOrigAll, dirSign, ...
    'VariableNames', {'变量名称', 'β标准化尺度', '标准误', 'z统计量', 'p值', ...
                      'β原始尺度', '影响方向'});
betaFile = fullfile(outDir, 'Optimized_Logistic_beta.xlsx');
if isfile(betaFile); delete(betaFile); end
writetable(betaTbl, betaFile, 'Sheet', 'β系数', 'WriteMode', 'overwritesheet');

fprintf('\n===== 优化Logistic回归 β 系数（Wald 检验） =====\n');
disp(betaTbl);

%% ---------- 2) 生成 Optimized_Logistic方程.txt（完整数学方程） ----------
eqFile = fullfile(outDir, 'Optimized_Logistic方程.txt');
fid = fopen(eqFile, 'w', 'n', 'UTF-8');           % 以 UTF-8 编码写入中文
if fid == -1
    error('[save_opt_result] 无法创建文件：%s', eqFile);
end

fprintf(fid, '========================================================\n');
fprintf(fid, ' 优化后 Logistic 客户流失概率判定方程（原始变量尺度，完整展开）\n');
fprintf(fid, '========================================================\n');
fprintf(fid, 'log(P/(1-P)) = %+.6f\n', beta0Orig);
for i = 2:numel(varNames)
    fprintf(fid, '    %+.6f × %s\n', betaOrigAll(i), varNames{i});
end
fprintf(fid, '\n其中 P 为客户流失概率，判定规则：P>=0.5 判为流失。\n');
fprintf(fid, '（上式与标准化模型等价：连续变量"在网时长（月）"已按 x=(x-mean)/std 还原。）\n');

fprintf(fid, '\n--------------------------------------------------------\n');
fprintf(fid, ' 标准化尺度判定方程（供内部预测使用）\n');
fprintf(fid, '--------------------------------------------------------\n');
fprintf(fid, 'log(P/(1-P)) = %+.6f\n', betaStdAll(1));
for i = 2:numel(varNames)
    fprintf(fid, '    %+.6f × %s(标准化)\n', betaStdAll(i), varNames{i});
end
fprintf(fid, '\n训练收敛：牛顿迭代 %d 次，最终误差 = %.3e。\n', stats.iter, stats.err);
fclose(fid);

fprintf('\n已保存：\n  %s\n  %s\n', betaFile, eqFile);

end
