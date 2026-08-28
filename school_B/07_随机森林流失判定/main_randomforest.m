%% main_randomforest.m —— 电信客户流失分析：随机森林客户流失判定模型（补充模型）
%  功能：读取 01_数据预处理/B_processed.csv，用随机森林二分类建立
%        客户流失概率判定模型，用于与问题2 的 Logistic 模型对比
%        （Logistic 可解释性强、β 显式；随机森林非线性、预测能力更强）。
%
%  目标变量：是否流失（Y=1 流失，Y=0 未流失）
%  输入变量（16 个，与问题2 Logistic 模型完全一致）：
%    分类变量（13 个，保持数值编码）：是否为老年人、是否有伴侣、是否有家属、
%      互联网服务类型、是否开通在线安全、是否开通在线备份、是否开通设备保护、
%      是否开通技术支持、是否开通电视流媒体、是否开通电影流媒体、合同类型、
%      是否使用电子账单、支付方式
%    连续变量（3 个，无需标准化）：在网时长（月）、月费用、总费用
%  删除：总费用为空（NaN）的样本（与 Logistic 相同）。
%
%  关键保证：与问题2 Logistic 模型完全一致的数据划分
%    （load_RF_data 内 rng(2026); perm=randperm(N); round(N*0.70)），
%    因此两个模型的训练集、测试集完全相同，评价指标可直接对比。
%
%  模型：随机森林二分类（100 棵树）
%    路径1（有统计/机器学习工具箱）：TreeBagger，OOB 置换特征重要性
%    路径2（无工具箱自动切换）：手动 Bootstrap + CART + Gini，节点分裂贡献重要性
%    每棵树输出流失概率，森林概率 = 平均投票比例；P>=0.5 判为流失。
%
%  输出：
%    RF_prediction_result.xlsx   测试集：客户编号 | 真实流失状态 | 预测概率P | 预测类别
%    RF_model_evaluation.xlsx    混淆矩阵(TP/TN/FP/FN) + Accuracy/Precision/Recall/F1
%    RF_ROC_curve.png            ROC 曲线（手动实现）及 AUC
%    RF_feature_importance.xlsx  排名 | 变量名称 | 重要性 | 重要性(%)
%    feature_importance.png      特征重要性水平条形图
%
%  环境：MATLAB R2025a（基础函数即可运行；有工具箱时自动使用 TreeBagger）
%  依赖函数：load_RF_data / train_randomforest / evaluate_RF / save_RF_result
%  运行方式：MATLAB 命令行直接执行 main_randomforest

clc; clear; close all;

%% ---------- 0) 定位工作目录（相对路径，不依赖绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

fprintf('======== 电信客户流失分析与挽留策略 —— 补充：随机森林流失判定模型 ========\n');

%% ---------- 1) 读取数据 + 划分数据集（与 Logistic 完全一致的划分） ----------
[Xtr, Ytr, Xte, Yte, keepIdxTest, vars, N, nTr, nTe] = load_RF_data();

%% ---------- 2) 训练随机森林（TreeBagger 优先，否则手动 CART） ----------
[model, method, importance, nTrees] = train_randomforest(Xtr, Ytr);

%% ---------- 3) 测试集预测：流失概率与类别（阈值 0.5） ----------
if strcmp(method, 'TreeBagger')
    % TreeBagger 路径：predict 返回 [预测类别, 各类别后验概率]
    [~, scores] = predict(model, Xte);
    cls = model.ClassNames;                       % 类别顺序：{'0','1'}
    if isa(cls, 'categorical'), cls = cellstr(cls); end
    colChurn = find(strcmp(cls, '1'), 1);         % 找到"流失"类所在列
    pTest = scores(:, colChurn);                  % 流失概率
else
    % 手动 CART 路径：森林概率 = 各棵树叶节点概率的平均（投票比例）
    pTest = zeros(nTe, 1);
    for t = 1:nTrees
        tree = model{t};
        for i = 1:nTe
            node = tree;
            while ~node.isLeaf                    % 沿分裂路径走到叶节点
                if Xte(i, node.feature) <= node.threshold
                    node = node.left;
                else
                    node = node.right;
                end
            end
            pTest(i) = pTest(i) + node.prob;      % 累计该树概率
        end
    end
    pTest = pTest / nTrees;
end
predClass = double(pTest >= 0.5);

fprintf('\n测试集样本数：%d（训练集 %d）\n', nTe, nTr);

%% ---------- 4) 模型评价：混淆矩阵 / 指标 / ROC / AUC ----------
evaluate_RF(Yte, pTest, pwd);

%% ---------- 5) 保存结果：预测结果 / 特征重要性 ----------
save_RF_result(keepIdxTest, Yte, pTest, predClass, vars, importance, pwd);

%% ---------- 6) 完成 ----------
fprintf('\n=====================================================\n');
fprintf('  随机森林客户流失判定模型建立完成。\n');
fprintf('  方法：%s，树数：%d。\n', method, nTrees);
fprintf('  结果文件目录：%s\n', pwd);
fprintf('=====================================================\n');
