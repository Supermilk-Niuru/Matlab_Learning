%% =====================================================================
%  2024国赛C题《农作物的种植策略》 —— 数据处理阶段（步骤3）
%  任务：建立“耕地类型—季次—时间—季节”对应关系表（seasonTable）
%
%  输入：
%      data_processed_step2.mat  （用于组合覆盖检查，只读取 allowedAll）
%      附件1.xlsx  （B44:B46 题目季次时间原文，用于核对，只读）
%
%  输出：
%      seasonTable              （字段：耕地类型 | 季次 | 时间 | 季节，10 行）
%      data_processed_step3.mat
%      data_processed_step3.xlsx
%
%  本步骤明确不做：
%      × 重茬约束 × 三年豆类约束 × 面积/产量/销售量约束 × 利润计算
%      × 线性/整数规划 × 遗传算法 × 蒙特卡洛 × 风险约束
%      × 不修改 plant2023；不修改 allowedAll/cropLandMatrix/
%        cropLandSeasonMatrix 等前面步骤数据；不生成热力图。
%
%  季节字段仅用于论文中的季节性文字描述，不作为优化约束。
%  平旱地/梯田/山坡地（及水浇地单季水稻）题目未给出具体月份，
%  统一记为“每年一季 / 单季”，不擅自添加月份。
% =====================================================================
clear; clc; close all;
fprintf('==============================================================\n');
fprintf('2024国赛C题 数据处理阶段（步骤3）\n');
fprintf('季次—季节表建立\n');
fprintf('==============================================================\n');

%% 0. 加载步骤2数据（用于组合覆盖检查，只读取，不修改）
S = load('data_processed_step2.mat');
allowedAll = S.allowedAll;
fprintf('\n已加载 data_processed_step2.mat（allowedAll 共 %d 行）\n', height(allowedAll));

%% 1. 建立 seasonTable（10 行）
%  时间字段：严格使用题目附件1原文给出的时间范围。
%  平旱地/梯田/山坡地 与 水浇地单季(水稻)：题目未给月份，记为“每年一季/单季”。
st_land   = ["平旱地";"梯田";"山坡地";"水浇地";"水浇地";"水浇地"; ...
             "普通大棚";"普通大棚";"智慧大棚";"智慧大棚"];
st_season = ["单季";"单季";"单季";"单季";"第一季";"第二季"; ...
             "第一季";"第二季";"第一季";"第二季"];
st_time   = ["每年一季";"每年一季";"每年一季";"每年一季"; ...
             "每年3月至6月前后";"每年7月至10月前后"; ...
             "每年5月至9月前后";"每年9月至下一年4月前后"; ...
             "每年3月至7月前后";"每年8月至下一年2月前后"];
st_ssn    = ["单季";"单季";"单季";"单季"; ...
             "春季至初夏";"夏季至秋季";"春末至夏季";"秋季至翌年春季"; ...
             "春季至夏季";"夏末至翌年冬季"];
seasonTable = table(st_land, st_season, st_time, st_ssn);
seasonTable.Properties.VariableNames = {'耕地类型','季次','时间','季节'};
fprintf('\nseasonTable 已建立：%d 行 × %d 列（字段：%s）\n', ...
    height(seasonTable), width(seasonTable), strjoin(seasonTable.Properties.VariableNames, ' | '));

%% 2. 与附件1原文核对（乡村种植的农作物 表 B44:B46 为题目季次时间说明）
fprintf('\n==============================================================\n');
fprintf('附件1原文核对（季次时间来源，B44:B46）\n');
fprintf('==============================================================\n');
srcText = repmat("", 3, 1);
try
    srcCell = readcell('附件1.xlsx', 'Sheet', '乡村种植的农作物', ...
        'Range', 'B44:B46', 'TextType', 'string');
    for k = 1:3
        if ~isempty(srcCell{k})
            srcText(k) = strrep(string(srcCell{k}), newline, ' ');
        end
    end
catch e
    fprintf('  警告：无法读取附件1 B44:B46（%s）\n', e.message);
end
for k = 1:3
    fprintf('  %s\n', srcText(k));
end

% 逐行核对月份范围（季节Table行号 -> 附件1源行 -> 应包含的月份标记）
monthchk_name = cell(6,1); monthchk_ok = false(6,1); monthchk_msg = cell(6,1);
spec = { ...   % {seasonTable行, 源行(1水浇地/2普通/3智慧), 应含标记}
    5, 1, {'3月','6月'};        % 水浇地 第一季
    6, 1, {'7月','10月'};       % 水浇地 第二季
    7, 2, {'5月','9月'};        % 普通大棚 第一季
    8, 2, {'9月','4月','下一年'};% 普通大棚 第二季
    9, 3, {'3月','7月'};        % 智慧大棚 第一季
   10, 3, {'8月','2月','下一年'}};% 智慧大棚 第二季
for i = 1:size(spec,1)
    r = spec{i,1}; sr = spec{i,2}; toks = spec{i,3};
    monthchk_name{i} = sprintf('%s %s', seasonTable.('耕地类型')(r), seasonTable.('季次')(r));
    ok = true; miss = {};
    for t = 1:numel(toks)
        if ~contains(srcText(sr), toks{t})
            ok = false; miss{end+1} = toks{t}; %#ok<AGROW>
        end
    end
    monthchk_ok(i) = ok;
    if ok
        monthchk_msg{i} = '月份范围与附件1原文一致 ✓';
    else
        monthchk_msg{i} = sprintf('附件1原文未找到 %s（可能措辞不同，请人工核对）', strjoin(miss, ', '));
    end
end
for i = 1:size(spec,1)
    tag = '✓'; if ~monthchk_ok(i), tag='✗'; end
    fprintf('  %s：%s %s\n', monthchk_name{i}, tag, monthchk_msg{i});
end

%% 3. 与 allowedAll 的组合覆盖检查
combos_allowed = unique(string(allowedAll.('PlotType')) + "|" + string(allowedAll.('Season')));
combos_season  = string(seasonTable.('耕地类型')) + "|" + string(seasonTable.('季次'));
missing = setdiff(combos_allowed, combos_season);
illegal = setdiff(combos_season, combos_allowed);

fprintf('\n==============================================================\n');
fprintf('【结果2】组合覆盖检查\n');
fprintf('==============================================================\n');
fprintf('allowedAll 中的地块类型+季次组合：共 %d 种\n', numel(combos_allowed));
fprintf('seasonTable 中的组合：          共 %d 种\n', numel(combos_season));
if isempty(missing)
    fprintf('  检查：✓ allowedAll 中的所有组合均已覆盖\n');
else
    fprintf('  检查：✗ seasonTable 缺失以下组合：\n');
    for i = 1:numel(missing)
        fprintf('      %s\n', missing(i));
    end
end
if isempty(illegal)
    fprintf('  检查：✓ seasonTable 不存在非法组合\n');
else
    fprintf('  检查：✗ seasonTable 存在题目未定义的组合：\n');
    for i = 1:numel(illegal)
        fprintf('      %s\n', illegal(i));
    end
end
if isempty(missing) && isempty(illegal)
    fprintf('  结论：两者组合集合完全一致 ✓\n');
end

%% 4. 命令窗口输出
fprintf('\n==============================================================\n');
fprintf('【结果1】seasonTable\n');
fprintf('==============================================================\n');
fprintf('    耕地类型 | 季次 | 时间 | 季节\n');
fprintf('    ----------------------------------------------------------\n');
for i = 1:height(seasonTable)
    fprintf('    %-6s | %-3s | %-14s | %s\n', ...
        seasonTable.('耕地类型')(i), seasonTable.('季次')(i), ...
        seasonTable.('时间')(i), seasonTable.('季节')(i));
end

fprintf('\n==============================================================\n');
fprintf('【结果3】季次统计\n');
fprintf('==============================================================\n');
SEASONS = ["单季"; "第一季"; "第二季"];
for s = SEASONS'
    n = numel(unique(seasonTable.('耕地类型')(string(seasonTable.('季次')) == s)));
    fprintf('    %s：%d 种地块类型\n', s, n);
end

%% 5. 冲突处理（若与题目规则冲突，不修改数据，打印后停止）
anyConflict = ~isempty(missing) || ~isempty(illegal) || any(~monthchk_ok);
if anyConflict
    fprintf('\n==============================================================\n');
    fprintf('附件数据冲突/题目规则冲突\n');
    fprintf('--------------------------------------------------------------\n');
    if ~isempty(missing)
        fprintf('  seasonTable 缺失的组合：%s\n', strjoin(missing, ', '));
    end
    if ~isempty(illegal)
        fprintf('  seasonTable 非法组合：%s\n', strjoin(illegal, ', '));
    end
    for i = 1:size(spec,1)
        if ~monthchk_ok(i)
            fprintf('  %s：%s\n', monthchk_name{i}, monthchk_msg{i});
        end
    end
    fprintf('程序未修改任何数据；已停止保存步骤3结果，等待人工判断。\n');
    fprintf('==============================================================\n');
    return;
end

%% 6. 保存结果
save('data_processed_step3.mat', 'seasonTable', 'combos_allowed', 'combos_season');
writetable(seasonTable, 'data_processed_step3.xlsx', 'Sheet', 'seasonTable');
fprintf('\n==============================================================\n');
fprintf('步骤3完成\n');
fprintf('==============================================================\n');
fprintf('保存：\n');
fprintf('    data_processed_step3.mat  （seasonTable）\n');
fprintf('    data_processed_step3.xlsx （seasonTable）\n');
fprintf('（未修改原始附件1.xlsx / 附件2.xlsx 与前面步骤数据）\n');
