%% =====================================================================
%  2024国赛C题《农作物的种植策略》 —— 数据处理阶段（步骤2）
%  任务：建立 “作物 × 地块类型 × 季次” 的可种植关系映射（可行域）
%
%  输入（步骤1已验证输出，本脚本不修改其内容，也不修改任何附件）：
%      data_processed_step1_corrected.mat
%        land / crops / plant2023 / allowedAll / stats2023_complete
%
%  输出：
%    【结果1】allowedAll（125 条）
%              字段：CropID CropName CropType PlotType Season SeasonCode Allowed
%    【结果2】cropLandMatrix（41×6）
%              行=41种作物，列=6种地块类型（平旱地/梯田/山坡地/水浇地/普通大棚/智慧大棚）
%              值=1(可种)/0(不可种)，不含季次
%    【结果3】cropLandSeasonMatrix（41×10）
%              行=41种作物，列=地块类型+季次，固定列序：
%              平旱地_单季,梯田_单季,山坡地_单季,水浇地_单季,水浇地_第一季,
%              水浇地_第二季,普通大棚_第一季,普通大棚_第二季,
%              智慧大棚_第一季,智慧大棚_第二季
%    热力图（中文标签，PingFang SC，避免乱码）：
%              crop_land_matrix.png / .fig
%              crop_land_season_matrix.png / .fig
%    数据文件：data_processed_step2.mat / .xlsx
%
%  明确不做（当前只建立“可行域”这一阶段）：
%     · 不做优化模型 / 决策变量 / intlinprog / 2024-2030 求解
%     · 不做轮作约束 / 豆类三年轮作 / 销售量约束 / 利润计算
%     · 不做问题2/问题3（不确定性、相关性）
%     · 不生成 result1_1 / result1_2 / result2.xlsx
%     · 不修改 附件1.xlsx / 附件2.xlsx / plant2023 原始种植数据
%
%  冲突处理：若发现附件数据与题目规则冲突，不修改数据，
%            打印“附件数据冲突/题目规则冲突”并指出具体作物、地块类型、季次，
%            等待人工判断。
% =====================================================================
clear; clc; close all;
fprintf('==============================================================\n');
fprintf('2024国赛C题 数据处理阶段（步骤2）\n');
fprintf('任务：建立“作物—地块类型—季次”可种植关系映射（可行域）\n');
fprintf('==============================================================\n');

%% 0. 加载步骤1数据
infile = 'data_processed_step1_corrected.mat';
S = load(infile);
land = S.land; crops = S.crops; plant2023 = S.plant2023;
allowedAll = S.allowedAll; stats2023_complete = S.stats2023_complete;
fprintf('\n已加载 %s（步骤1验证通过；本步骤不修改其数据逻辑）\n', infile);
fprintf('  land 地块表 %d 行；crops 作物表 %d 行\n', height(land), height(crops));
fprintf('  allowedAll 可种植关系 %d 行；stats2023_complete 经济参数 %d 行\n', ...
    height(allowedAll), height(stats2023_complete));

%% 1. 地块类型 / 季次 定义（与题目规则一致）
PLOT_TYPES   = ["平旱地"; "梯田"; "山坡地"; "水浇地"; "普通大棚"; "智慧大棚"];
SEASON_NAMES = ["单季"; "第一季"; "第二季"];
SEASON_CODES = [1; 2; 3];   % 单季=1，第一季=2，第二季=3
season_map = containers.Map(cellstr(string(SEASON_NAMES)), num2cell(SEASON_CODES));

fprintf('\n地块类型（6种）：%s\n', strjoin(PLOT_TYPES, '、'));
fprintf('季次（3种）：单季(编码1)、第一季(编码2)、第二季(编码3)\n');
fprintf('题目季次规则：平旱地/梯田/山坡地仅单季；水浇地=水稻单季 或 两季蔬菜；\n');
fprintf('              普通大棚=第一季蔬菜+第二季食用菌；智慧大棚=第一季+第二季蔬菜\n');

%% 2. 【结果1】allowedAll：在步骤1基础上增加 SeasonCode 列
nA = height(allowedAll);
allowedAll.('SeasonCode') = zeros(nA,1);
for i = 1:nA
    sname = char(string(allowedAll.('Season')(i)));
    if isKey(season_map, sname)
        allowedAll.('SeasonCode')(i) = season_map(sname);
    else
        fprintf('警告：未知季次名称 [%s]（第%d行）\n', sname, i);
    end
end
% 列顺序：CropID CropName CropType PlotType Season SeasonCode Allowed
allowedAll = allowedAll(:, {'CropID','CropName','CropType','PlotType','Season', ...
                             'SeasonCode','Allowed'});
fprintf('\n【结果1】allowedAll：%d 行，字段：%s\n', height(allowedAll), ...
    strjoin(allowedAll.Properties.VariableNames, ', '));
fprintf('  Allowed=1 的行数：%d（应为全部行）\n', sum(allowedAll.('Allowed')==1));

%% 3. 【结果2】cropLandMatrix（41×6）
nCrop  = height(crops);
nPlot  = numel(PLOT_TYPES);
cidAll = allowedAll.('CropID');     % double
ptAll  = string(allowedAll.('PlotType'));
seAll  = string(allowedAll.('Season'));

cropLandMatrix = zeros(nCrop, nPlot);
for i = 1:nCrop
    cid_i = crops.('CropID')(i);
    rowmask = cidAll == cid_i;
    for k = 1:nPlot
        cropLandMatrix(i,k) = any(rowmask & ptAll == PLOT_TYPES(k));
    end
end
fprintf('\n【结果2】cropLandMatrix：%d×%d（行=作物，列=地块类型，1=可种）\n', ...
    size(cropLandMatrix,1), size(cropLandMatrix,2));

%% 4. 【结果3】cropLandSeasonMatrix（41×10）
colinfo = { ...
    '平旱地_单季','平旱地','单季'; ...
    '梯田_单季','梯田','单季'; ...
    '山坡地_单季','山坡地','单季'; ...
    '水浇地_单季','水浇地','单季'; ...
    '水浇地_第一季','水浇地','第一季'; ...
    '水浇地_第二季','水浇地','第二季'; ...
    '普通大棚_第一季','普通大棚','第一季'; ...
    '普通大棚_第二季','普通大棚','第二季'; ...
    '智慧大棚_第一季','智慧大棚','第一季'; ...
    '智慧大棚_第二季','智慧大棚','第二季'};
nCol = size(colinfo,1);
COL_NAMES = colinfo(:,1)';

cropLandSeasonMatrix = zeros(nCrop, nCol);
for i = 1:nCrop
    cid_i = crops.('CropID')(i);
    rowmask = cidAll == cid_i;
    for c = 1:nCol
        cropLandSeasonMatrix(i,c) = any(rowmask & ...
            ptAll == string(colinfo{c,2}) & seAll == string(colinfo{c,3}));
    end
end
fprintf('\n【结果3】cropLandSeasonMatrix：%d×%d（行=作物，列=地块类型+季次）\n', ...
    size(cropLandSeasonMatrix,1), size(cropLandSeasonMatrix,2));
if sum(cropLandSeasonMatrix(:)) ~= height(allowedAll)
    fprintf('警告：cropLandSeasonMatrix 非零元素总数(%d) 与 allowedAll 行数(%d) 不一致\n', ...
        sum(cropLandSeasonMatrix(:)), height(allowedAll));
end

%% 5. 命令窗口输出 ①：41种作物的可种植地块类型
fprintf('\n==============================================================\n');
fprintf('① 41种作物的可种植地块类型\n');
fprintf('==============================================================\n');
for i = 1:nCrop
    cid_i = crops.('CropID')(i);
    nm = char(string(crops.('CropName')(i)));
    ty = char(string(crops.('CropType')(i)));
    rowmask = cidAll == cid_i;
    parts = string([]);
    for k = 1:nPlot
        m = rowmask & ptAll == PLOT_TYPES(k);
        if any(m)
            ss = strjoin(unique(seAll(m)), '+');
            parts = [parts, char(PLOT_TYPES(k)) + "(" + char(ss) + ")"]; %#ok<AGROW>
        end
    end
    line = strjoin(parts, '  ');
    fprintf('%2d %-6s [%s]: %s\n', double(cid_i), nm, ty, char(line));
end

%% 6. 命令窗口输出 ②：每种地块类型允许种植的作物数量（去重）
fprintf('\n==============================================================\n');
fprintf('② 每种地块类型允许种植的作物数量（跨季次去重）\n');
fprintf('==============================================================\n');
for k = 1:nPlot
    cids_k = unique(cidAll(ptAll == PLOT_TYPES(k)));
    fprintf('  %-8s：%d 种\n', PLOT_TYPES(k), numel(cids_k));
end

%% 7. 命令窗口输出 ③：每种“地块类型+季次”的允许作物数量
fprintf('\n==============================================================\n');
fprintf('③ 每种“地块类型+季次”的允许作物数量\n');
fprintf('==============================================================\n');
tot = 0;
for c = 1:nCol
    n_ = sum(cropLandSeasonMatrix(:,c));
    tot = tot + n_;
    fprintf('  %-12s：%d 种\n', COL_NAMES{c}, n_);
end
fprintf('  合计（允许关系总数）：%d\n', tot);

%% 8. 命令窗口输出 ⑤：最终矩阵大小
fprintf('\n==============================================================\n');
fprintf('⑤ 最终矩阵大小\n');
fprintf('==============================================================\n');
fprintf('  allowedAll             ：%d 行 × %d 列\n', size(allowedAll,1), size(allowedAll,2));
fprintf('  cropLandMatrix         ：%d 行 × %d 列\n', size(cropLandMatrix,1), size(cropLandMatrix,2));
fprintf('  cropLandSeasonMatrix   ：%d 行 × %d 列\n', size(cropLandSeasonMatrix,1), size(cropLandSeasonMatrix,2));

%% 9. 命令窗口输出 ④：自动检查（10项）
fprintf('\n==============================================================\n');
fprintf('④ 自动检查（10项）\n');
fprintf('==============================================================\n');
ck_name = cell(10,1); ck_ok = false(10,1); ck_msg = cell(10,1);

% --- 检查1：每种作物至少 1 个可种地块类型 ---
ck_name{1} = '每种作物至少有一个可种植地块类型';
r1 = sum(cropLandMatrix,2);
if all(r1>=1)
    ck_ok(1)=true; ck_msg{1}='41 种作物均至少可种于 1 种地块类型 ✓';
else
    ck_msg{1} = sprintf('作物 %s 无可种地块类型', num2str(find(r1<1)'));
end

% --- 检查2：每种地块类型至少 1 种可种作物 ---
ck_name{2} = '每种地块类型至少有一种可种作物';
r2 = sum(cropLandMatrix,1);
if all(r2>=1)
    ck_ok(2)=true; ck_msg{2}='6 种地块类型均至少可种 1 种作物 ✓';
else
    ck_msg{2} = sprintf('地块类型 %s 无作物', strjoin(PLOT_TYPES(r2<1),','));
end

% --- 检查3：平旱地/梯田/山坡地：只允许 粮食(非水稻) 且 单季 ---
ck_name{3} = '平旱地/梯田/山坡地 只允许粮食(除水稻)且单季';
bad3 = {};
for k = 1:3
    m = ptAll == PLOT_TYPES(k);
    subcids = cidAll(m); subse = seAll(m);
    for j = 1:numel(subcids)
        ci = subcids(j);
        cty = char(string(crops.('CropType')(crops.('CropID')==ci)));
        cnm = char(string(crops.('CropName')(crops.('CropID')==ci)));
        okty = contains(cty,'粮食') && ci ~= 16;
        okse = string(subse(j)) == "单季";
        if ~(okty && okse)
            bad3{end+1} = sprintf('%s(单季): 作物%d %s [%s]', PLOT_TYPES(k), ci, cnm, cty); % ok<AGROW>
        end
    end
end
if isempty(bad3)
    ck_ok(3)=true; ck_msg{3}='三类地块均为粮食(非水稻)+单季 ✓';
else
    ck_msg{3} = strjoin(bad3, '；');
end

% --- 检查4：水浇地 单季：只允许 水稻 ---
ck_name{4} = '水浇地单季 只允许 水稻';
m4 = ptAll == "水浇地" & seAll == "单季";
cids4 = sort(cidAll(m4));
if isequal(cids4, 16)
    ck_ok(4)=true; ck_msg{4}='水浇地单季仅作物16(水稻) ✓';
else
    ck_msg{4} = sprintf('水浇地单季作物集合=[%s]，应为[16]', num2str(cids4'));
end

% --- 检查5：水浇地 第一季/第二季：只允许 蔬菜（含蔬菜豆类） ---
ck_name{5} = '水浇地 第一季/第二季 只允许蔬菜';
bad5 = {};
for se = ["第一季","第二季"]
    m = ptAll == "水浇地" & seAll == se;
    for ci = cidAll(m)'
        cty = char(string(crops.('CropType')(crops.('CropID')==ci)));
        if ~contains(cty,'蔬菜')
            bad5{end+1} = sprintf('水浇地%s: 作物%d %s [%s]', se, ci, ...
                char(string(crops.('CropName')(crops.('CropID')==ci))), cty); % ok<AGROW>
        end
    end
end
if isempty(bad5)
    ck_ok(5)=true; ck_msg{5}='水浇地两季均为蔬菜类 ✓';
else
    ck_msg{5} = strjoin(bad5,'；');
end

% --- 检查6：普通大棚 第一季：只允许 蔬菜 ---
ck_name{6} = '普通大棚第一季 只允许蔬菜';
m6 = ptAll == "普通大棚" & seAll == "第一季";
bad6 = {};
for ci = cidAll(m6)'
    cty = char(string(crops.('CropType')(crops.('CropID')==ci)));
    if ~contains(cty,'蔬菜')
        bad6{end+1} = sprintf('作物%d %s [%s]', ci, ...
            char(string(crops.('CropName')(crops.('CropID')==ci))), cty); % ok<AGROW>
    end
end
if isempty(bad6)
    ck_ok(6)=true; ck_msg{6}=sprintf('普通大棚第一季 %d 种全部为蔬菜 ✓', sum(m6));
else
    ck_msg{6} = strjoin(bad6,';');
end

% --- 检查7：普通大棚 第二季：只允许 食用菌 ---
ck_name{7} = '普通大棚第二季 只允许食用菌';
m7 = ptAll == "普通大棚" & seAll == "第二季";
bad7 = {};
for ci = cidAll(m7)'
    cty = char(string(crops.('CropType')(crops.('CropID')==ci)));
    if ~contains(cty,'食用菌')
        bad7{end+1} = sprintf('作物%d %s [%s]', ci, ...
            char(string(crops.('CropName')(crops.('CropID')==ci))), cty); % ok<AGROW>
    end
end
if isempty(bad7)
    ck_ok(7)=true; ck_msg{7}=sprintf('普通大棚第二季 %d 种全部为食用菌 ✓', sum(m7));
else
    ck_msg{7} = strjoin(bad7,'；');
end

% --- 检查8：智慧大棚 第一季/第二季：只允许 蔬菜 ---
ck_name{8} = '智慧大棚 第一季/第二季 只允许蔬菜';
bad8 = {};
for se = ["第一季","第二季"]
    m = ptAll == "智慧大棚" & seAll == se;
    for ci = cidAll(m)'
        cty = char(string(crops.('CropType')(crops.('CropID')==ci)));
        if ~contains(cty,'蔬菜')
            bad8{end+1} = sprintf('智慧大棚%s: 作物%d %s [%s]', se, ci, ...
                char(string(crops.('CropName')(crops.('CropID')==ci))), cty); % ok<AGROW>
        end
    end
end
if isempty(bad8)
    ck_ok(8)=true; ck_msg{8}='智慧大棚两季均为蔬菜类 ✓';
else
    ck_msg{8} = strjoin(bad8,'；');
end

% --- 检查9：智慧大棚第一季集合 == 普通大棚第一季集合 ---
ck_name{9} = '智慧大棚第一季集合 == 普通大棚第一季集合';
sa = sort(cidAll(ptAll=="智慧大棚" & seAll=="第一季"));
sb = sort(cidAll(ptAll=="普通大棚" & seAll=="第一季"));
if isequal(sa, sb)
    ck_ok(9)=true; ck_msg{9}=sprintf('两季集合完全一致（各 %d 种，作物17-34）✓', numel(sa));
else
    ck_msg{9} = sprintf('智慧=[%s] 普通=[%s]', num2str(sa'), num2str(sb'));
end

% --- 检查10：每个 Allowed=1 组合 在 stats2023_complete 中都有经济参数 ---
ck_name{10} = 'Allowed=1 组合均存在经济参数';
keyA = string(cidAll) + "|" + ptAll + "|" + seAll;
keyS = string(stats2023_complete.('CropID')) + "|" + ...
       string(stats2023_complete.('PlotType')) + "|" + ...
       string(stats2023_complete.('Season'));
miss10 = setdiff(keyA, keyS);
if isempty(miss10)
    ck_ok(10)=true; ck_msg{10}='全部 125 个允许组合均有经济参数（无缺失）✓';
else
    ck_msg{10} = sprintf('缺失 %d 个组合（见下方冲突清单）', numel(miss10));
end

% --- 打印检查结果 ---
fprintf('\n---- 检查结果 ----\n');
allpass = true;
for i = 1:10
    tag = '✓'; if ~ck_ok(i), tag='✗'; allpass=false; end
    fprintf('  %2d) %s\n       %s %s\n', i, ck_name{i}, tag, ck_msg{i});
end
if allpass
    fprintf('\n== 结论：10项自动检查全部通过 ==\n');
else
    fprintf('\n== 结论：10项自动检查存在未通过项 ==\n');
end

% --- 冲突处理：不修改数据，打印冲突细节，等待人工判断 ---
if ~allpass
    fprintf('\n==============================================================\n');
    fprintf('附件数据冲突/题目规则冲突\n');
    fprintf('--------------------------------------------------------------\n');
    for i = 1:10
        if ~ck_ok(i)
            fprintf('  检查%d：%s\n      %s\n', i, ck_name{i}, ck_msg{i});
        end
    end
    if ~isempty(miss10)
        fprintf('  缺少经济参数的允许组合（作物 | 地块类型 | 季次）：\n');
        for i = 1:numel(miss10)
            fprintf('      %s\n', miss10(i));
        end
    end
    fprintf('程序未修改任何数据；已停止生成步骤2结果，等待人工判断。\n');
    fprintf('==============================================================\n');
    return;
end

%% 10. 关系关联图（热力图，中文标签，PingFang SC 避免乱码）
cmap2 = [0.93 0.93 0.93; 0.10 0.52 0.93];   % 0=浅灰，1=蓝色
cropnames = arrayfun(@(i) sprintf('%d %s', double(crops.('CropID')(i)), ...
    char(string(crops.('CropName')(i)))), 1:nCrop, 'UniformOutput', false);
cropnames = string(cropnames);

fprintf('\n生成热力图…\n');

fig1 = figure('Color','w','Position',[80 80 880 780]);
h1 = heatmap(string(PLOT_TYPES), cropnames, cropLandMatrix);
h1.Title = '作物 × 地块类型 可种植关系矩阵';
h1.FontName = 'PingFang SC';
h1.FontSize = 8;
h1.Colormap = cmap2;
h1.CellLabelColor = 'none';
h1.ColorbarVisible = 'off';
h1.XLabel = '地块类型';
h1.YLabel = '作物';
exportgraphics(fig1, 'crop_land_matrix.png', 'Resolution', 220);
saveas(fig1, 'crop_land_matrix.fig');
% close(fig1);

fig2 = figure('Color','w','Position',[100 100 1120 780]);
h2 = heatmap(string(COL_NAMES), cropnames, cropLandSeasonMatrix);
h2.Title = '作物 × (地块类型+季次) 可种植关系矩阵';
h2.FontName = 'PingFang SC';
h2.FontSize = 8;
h2.Colormap = cmap2;
h2.CellLabelColor = 'none';
h2.ColorbarVisible = 'off';
h2.XLabel = '地块类型 + 季次';
h2.YLabel = '作物';
exportgraphics(fig2, 'crop_land_season_matrix.png', 'Resolution', 220);
saveas(fig2, 'crop_land_season_matrix.fig');
% close(fig2);
fprintf('  已保存：crop_land_matrix.png/.fig、crop_land_season_matrix.png/.fig\n');

%% 11. 保存结果文件
save('data_processed_step2.mat', ...
    'land','crops','plant2023','stats2023_complete', ...
    'allowedAll','cropLandMatrix','cropLandSeasonMatrix', ...
    'PLOT_TYPES','SEASON_NAMES','SEASON_CODES','COL_NAMES','colinfo', ...
    'ck_name','ck_ok','ck_msg');
fprintf('已保存 data_processed_step2.mat\n');

% ---------- xlsx ----------
xlsfile = 'data_processed_step2.xlsx';

% sheet1: allowedAll
writetable(allowedAll, xlsfile, 'Sheet', 'allowedAll');

% sheet2: cropLandMatrix（CropID/CropName + 6 个地块类型列）
colcell = cell(1, nPlot+2);
colcell{1} = crops.('CropID');
colcell{2} = crops.('CropName');
for k = 1:nPlot
    colcell{k+2} = cropLandMatrix(:,k);
end
T1 = table(colcell{:});
T1.Properties.VariableNames = [{'CropID','CropName'}, cellstr(PLOT_TYPES)'];
writetable(T1, xlsfile, 'Sheet', 'cropLandMatrix');

% sheet3: cropLandSeasonMatrix（CropID/CropName + 10 个“地块类型+季次”列）
colcell2 = cell(1, nCol+2);
colcell2{1} = crops.('CropID');
colcell2{2} = crops.('CropName');
for c = 1:nCol
    colcell2{c+2} = cropLandSeasonMatrix(:,c);
end
T2 = table(colcell2{:});
T2.Properties.VariableNames = [{'CropID','CropName'}, COL_NAMES];
writetable(T2, xlsfile, 'Sheet', 'cropLandSeasonMatrix');

% sheet4: 检查结果
okstr = {'未通过'; '通过'};
T3 = table((1:10)', ck_name, okstr(double(ck_ok)+1), ck_msg);
T3.Properties.VariableNames = {'序号','检查项','结果','说明'};
writetable(T3, xlsfile, 'Sheet', '检查结果');
fprintf('已保存 data_processed_step2.xlsx\n');

%% 12. 收尾汇总
fprintf('\n==============================================================\n');
fprintf('数据处理阶段（步骤2）完成。\n');
fprintf('  结果文件：\n');
fprintf('    data_processed_step2.mat / .xlsx\n');
fprintf('    crop_land_matrix.png / .fig\n');
fprintf('    crop_land_season_matrix.png / .fig\n');
fprintf('（未修改原始附件1.xlsx / 附件2.xlsx，plant2023 未做任何改动）\n');
fprintf('==============================================================\n');
