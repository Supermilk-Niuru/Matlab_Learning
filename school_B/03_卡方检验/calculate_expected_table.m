function E = calculate_expected_table(O)
% CALCULATE_EXPECTED_TABLE 计算理论频数（期望频数）矩阵 E
%   公式：E_ij = (第 i 行合计 × 第 j 列合计) / 总人数 N
%        = row_sum_i × col_sum_j / N
%
%   输入：
%     O —— r×2 观察频数矩阵（类别 × [未流失, 流失]）
%   输出：
%     E —— r×2 理论频数矩阵
%          性质：E 的行和 = 观察频数行和，E 的列和 = 观察频数列和，E 的总和 = N

rowSums = sum(O, 2);      % 行和（r×1）
colSums = sum(O, 1);      % 列和（1×2）
N       = sum(rowSums);   % 总人数

% E_ij = row_sum_i × col_sum_j / N（行向量 × 列向量 = 外积矩阵）
E = (rowSums * colSums) / N;

end
