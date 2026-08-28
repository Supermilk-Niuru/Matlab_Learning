function compare_models(optM, outDir)
% COMPARE_MODELS 模型对比：原始 Logistic 模型 vs 优化 Logistic 模型
%
%   优化模型的评价指标由 evaluate_opt_model 返回（同一测试集）。
%   原始模型（16 变量）的评价指标从 06_Logistic流失判定/model_evaluation.xlsx
%   的"评价指标"工作表读取（避免重新运行原始模型，也不覆盖其任何文件）。
%
%   输出文件（保存在 outDir）：
%     Model_comparison.xlsx   模型名称 | 变量数量 | Accuracy | Precision |
%                             Recall | F1-score | AUC
%
%   若找不到原始模型评价文件，原始模型指标置为缺失并给出警告。

if nargin < 2, outDir = pwd; end

%% ---------- 1) 读取原始 Logistic 模型评价指标 ----------
origFile = fullfile(pwd, '..', 'model_evaluation.xlsx');
try
    T = readtable(origFile, 'Sheet', '评价指标', 'VariableNamingRule', 'preserve');
    origAcc = findMetric(T, 'Accuracy');
    origPrec = findMetric(T, 'Precision');
    origRec  = findMetric(T, 'Recall');
    origF1   = findMetric(T, 'F1');
    origAUC  = findMetric(T, 'AUC');
    fprintf('已读取原始 Logistic 模型评价指标（%s）。\n', origFile);
catch
    origAcc = NaN; origPrec = NaN; origRec = NaN; origF1 = NaN; origAUC = NaN;
    warning('未找到原始模型评价文件：%s，原始模型指标置为缺失。', origFile);
end

%% ---------- 2) 组装对比表 ----------
compTbl = table({'原始Logistic模型'; '优化Logistic模型'}, ...
                [16; 13], ...
                [origAcc;        optM.Accuracy], ...
                [origPrec;       optM.Precision], ...
                [origRec;        optM.Recall], ...
                [origF1;         optM.F1], ...
                [origAUC;        optM.AUC], ...
    'VariableNames', {'模型名称', '变量数量', 'Accuracy', 'Precision', ...
                      'Recall', 'F1-score', 'AUC'});

%% ---------- 3) 保存 Model_comparison.xlsx ----------
compFile = fullfile(outDir, 'Model_comparison.xlsx');
if isfile(compFile); delete(compFile); end
writetable(compTbl, compFile, 'Sheet', '模型对比', 'WriteMode', 'overwritesheet');

fprintf('\n===== 模型对比（同一测试集） =====\n');
disp(compTbl);
fprintf('已保存：%s\n', compFile);

end

%% ---------- 局部函数：从指标表中按名称提取数值 ----------
function v = findMetric(T, key)
% FINDMETRIC 在"指标"列中查找包含 key 的行，返回对应"数值"。
idx = find(contains(T.('指标'), key), 1);
if isempty(idx)
    v = NaN;
else
    v = T.('数值')(idx);
end
end
