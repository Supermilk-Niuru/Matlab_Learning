%% main_EDA_basic.m —— 电信客户流失分析：基础探索性数据分析（EDA）
%  功能：读取 B_processed.csv →
%        步骤一（整体客户流失情况分析）
%        步骤二（分类变量单因素流失分析）
%        步骤三（连续变量流失差异分析）
%        → 输出 Excel（EDA_basic_result.xlsx）与分类图片
%  说明：本阶段仅进行数据探索与可视化，
%        不训练模型、不预测流失概率、不计算特征重要性、
%        不进行相关性分析、标准化、归一化或特征工程。
%  环境：MATLAB R2025a
%  依赖函数：create_result_folder / load_processed_data /
%            analyze_overall_churn / analyze_categorical_churn /
%            analyze_numeric_churn / draw_bar_pie / draw_box_violin /
%            save_EDA_result
%  运行方式：在 MATLAB 命令行直接执行  main_EDA_basic

clc; clear; close all;

%% ---------- 0) 定位工作目录（避免绝对路径） ----------
scriptDir = fileparts(mfilename('fullpath'));
if ~isempty(scriptDir)
    cd(scriptDir);
end

%% ---------- 1) 创建结果文件夹 ----------
[overallDir, singleDir, numericDir] = create_result_folder();

%% ---------- 2) 读取数据 ----------
data = load_processed_data();

%% ---------- 3) 步骤一：整体客户流失情况分析 ----------
overallTbl = analyze_overall_churn(data, overallDir);

%% ---------- 4) 步骤二：分类变量单因素流失分析 ----------
catResult = analyze_categorical_churn(data, singleDir);

%% ---------- 5) 步骤三：连续变量流失差异分析 ----------
numericTbl = analyze_numeric_churn(data, numericDir);

%% ---------- 6) 保存 Excel 分析结果 ----------
save_EDA_result(overallTbl, catResult, numericTbl);

%% ---------- 7) 完成 ----------
fprintf('========================================\n');
fprintf('  EDA基础分析完成。\n');
fprintf('  图片输出目录：\n');
fprintf('    %s\n', overallDir);
fprintf('    %s\n', singleDir);
fprintf('    %s\n', numericDir);
fprintf('  Excel 结果：%s\n', fullfile(pwd, 'EDA_basic_result.xlsx'));
fprintf('========================================\n');
