%% =====================================================================
%  2024国赛C题《农作物的种植策略》 —— 数据处理阶段（步骤4）
%  任务：整理农作物经济参数表（只做数据整理与映射，不做优化建模）
%
%  输入：
%      data_processed_step2.mat  —— land / crops / plant2023 / allowedAll /
%                                   stats2023_complete
%      data_processed_step3.mat  —— seasonTable
%      （说明：步骤3只保存了 seasonTable，其余变量按题目要求从步骤2加载）
%
%  输出：
%      seasonCropEconomics（表1）—— 按“季次+作物”组织，因同一作物+季次在
%           不同地块类型下经济参数不同，必须保留“地块类型”列，不强行合并
%      landCropEconomics（表2）—— 按“地块类型+季次+作物”组织唯一经济参数
%      data_processed_step4.mat / .xlsx
%
%  关键要求：
%      · 销售价格保留附件2原始区间字符串（如 "2.50-4.00"），不取平均值；
%      · 智慧大棚第一季参数 = 普通大棚第一季同作物参数（题目规定），不得重算；
%      · stats2023_complete 原样保留，不修改原始数据逻辑。
%
%  本步骤明确不做：
%      × 利润/收入/成本/产量/销售量计算 × 销售量约束 × 取价格平均值
%      × 优化/线性/整数规划 × 遗传算法 × 蒙特卡洛 × 风险约束
%      × 重茬约束 × 三年豆类约束 × 利润图 × 任何预测
% =====================================================================
clear; clc; close all;
fprintf('==============================================================\n');
fprintf('2024国赛C题 数据处理阶段（步骤4）\n');
fprintf('农作物经济参数整理\n');
fprintf('==============================================================\n');

%% 0. 加载数据
S2 = load('data_processed_step2.mat');
S3 = load('data_processed_step3.mat');
land = S2.land; crops = S2.crops; plant2023 = S2.plant2023;
allowedAll = S2.allowedAll; stats2023_complete = S2.stats2023_complete;
seasonTable = S3.seasonTable;
fprintf('\n已加载：\n');
fprintf('  stats2023_complete 经济参数：%d 行（含智慧大棚第一季补全）\n', height(stats2023_complete));
fprintf('  allowedAll 可种植关系：%d 行；crops 作物表：%d 行；land 地块表：%d 行；seasonTable：%d 行\n', ...
    height(allowedAll), height(crops), height(land), height(seasonTable));

%% 1. 读取经济参数基本字段
st = stats2023_complete;
cid = double(st.('CropID'));
cnm = string(st.('CropName'));
pt  = string(st.('PlotType'));
se  = string(st.('Season'));
yl  = st.('YieldPerMu');      % 亩产量：斤/亩
co  = st.('CostPerMu');       % 种植成本：元/亩
pr  = string(st.('PricePerJin')); % 销售价格：元/斤（保留原始区间字符串）

% 排序依据（保持与前面步骤一致）
seMap = containers.Map({'单季','第一季','第二季'}, {1,2,3});
ptMap = containers.Map({'平旱地','梯田','山坡地','水浇地','普通大棚','智慧大棚'}, {1,2,3,4,5,6});
n = numel(cid);
seOrd = zeros(n,1); ptOrd = zeros(n,1);
for i = 1:n
    seOrd(i) = seMap(char(se(i)));
    ptOrd(i) = ptMap(char(pt(i)));
end

%% 2. 表1：seasonCropEconomics（季次+作物 组织，保留地块类型）
%  数据事实：同一“作物+季次”在不同地块类型下经济参数不同（检查3确认），
%  因此不能按 (季次,作物) 合并，必须保留“地块类型”列建立唯一组合记录。
[~, ord1] = sortrows([seOrd cid ptOrd]);
seasonCropEconomics = table(se(ord1), cid(ord1), cnm(ord1), pt(ord1), ...
                            yl(ord1), co(ord1), pr(ord1));
seasonCropEconomics.Properties.VariableNames = ...
    {'季次','作物编号','作物名称','地块类型','亩产量/斤','种植成本/(元/亩)','销售价格/(元/斤)'};

nCombos_CS = numel(unique(cid + "|" + se));   % 作物+季次 组合数
fprintf('\n表1 说明：同一“作物+季次”在不同地块类型下参数不同，必须保留“地块类型”列，\n');
fprintf('         %d 条唯一参数记录（对应 %d 个 作物+季次 组合），不做强行合并。\n', ...
    height(seasonCropEconomics), nCombos_CS);

%% 3. 表2：landCropEconomics（地块类型+季次+作物 组织）
%  数据事实：同一“作物+地块类型”在不同季次下参数不同（如智慧大棚第一季与第二季），
%  因此必须保留“季次”字段。
[~, ord2] = sortrows([ptOrd seOrd cid]);
landCropEconomics = table(pt(ord2), se(ord2), cid(ord2), cnm(ord2), ...
                          yl(ord2), co(ord2), pr(ord2));
landCropEconomics.Properties.VariableNames = ...
    {'地块类型','季次','作物编号','作物名称','亩产量/斤','种植成本/(元/亩)','销售价格/(元/斤)'};

%% 4. 七项检查
keyAll = unique(string(allowedAll.('CropID')) + "|" + ...
                string(allowedAll.('PlotType')) + "|" + string(allowedAll.('Season')));
keySt  = cid + "|" + pt + "|" + se;

% 检查1：Allowed=1 但 stats2023_complete 无参数
miss1 = setdiff(keyAll, keySt);

% 检查2：stats2023_complete 中存在 allowedAll 之外的组合（Allowed=0 却有参数）
illegal2 = setdiff(keySt, keyAll);

% 检查3：(CropID+PlotType+Season) 唯一对应 (Yield+Cost+Price)
uk = unique(keySt);
dup3 = {};
for i = 1:numel(uk)
    mm = keySt == uk(i);
    tri = unique([yl(mm) co(mm) string(pr(mm))], 'rows');
    if size(tri,1) > 1
        dup3{end+1} = uk(i); %#ok<AGROW>
    end
end
nDupRow = n - numel(uk);   % 同一组合重复出现次数（含参数相同的情况也计为重复）

% 检查4：智慧大棚第一季 与 普通大棚第一季 参数一致
gS = pt == "智慧大棚" & se == "第一季";
gP = pt == "普通大棚" & se == "第一季";
sC = sort(cid(gS)); pC = sort(cid(gP));
ck4_ok = true; ck4_msg = '';
if ~isequal(sC, pC)
    ck4_ok = false; ck4_msg = '两个季次的作物集合不一致';
else
    bad4 = {};
    for i = 1:numel(sC)
        ci = sC(i);
        riS = find(gS & cid==ci); riP = find(gP & cid==ci);
        if ~(yl(riS)==yl(riP) && co(riS)==co(riP) && pr(riS)==pr(riP))
            bad4{end+1} = sprintf('作物%d %s', ci, cnm(find(cid==ci,1))); %#ok<AGROW>
        end
    end
    if isempty(bad4)
        ck4_msg = sprintf('%d 种作物 Yield/Cost/Price 全部一致', numel(sC));
    else
        ck4_ok = false; ck4_msg = strjoin(bad4, '；');
    end
end

% 检查5：经济参数中的作物都在 crops 表
missing5 = setdiff(unique(cid), double(crops.('CropID')));
% 检查6：经济参数中的地块类型都在 land 表
missing6 = setdiff(unique(pt), unique(string(land.('PlotType'))));
% 检查7：经济参数中的季次都在 seasonTable
missing7 = setdiff(unique(se), unique(string(seasonTable.('季次'))));

%% 5. 命令窗口输出
fprintf('\n==============================================================\n');
fprintf('【结果1】季次与农作物经济参数表\n');
fprintf('==============================================================\n');
fprintf('    季次 | 作物编号 | 作物名称 | 地块类型 | 亩产量/斤 | 种植成本/(元/亩) | 销售价格/(元/斤)\n');
fprintf('    -----------------------------------------------------------------------------\n');
for i = 1:height(seasonCropEconomics)
    fprintf('    %-3s | %6d | %-4s | %-4s | %6g | %5g | %s\n', ...
        seasonCropEconomics.('季次')(i), seasonCropEconomics.('作物编号')(i), ...
        seasonCropEconomics.('作物名称')(i), seasonCropEconomics.('地块类型')(i), ...
        seasonCropEconomics.('亩产量/斤')(i), seasonCropEconomics.('种植成本/(元/亩)')(i), ...
        seasonCropEconomics.('销售价格/(元/斤)')(i));
end

fprintf('\n==============================================================\n');
fprintf('【结果2】地块类型与农作物经济参数表\n');
fprintf('==============================================================\n');
fprintf('    地块类型 | 季次 | 作物编号 | 作物名称 | 亩产量/斤 | 种植成本/(元/亩) | 销售价格/(元/斤)\n');
fprintf('    -----------------------------------------------------------------------------\n');
for i = 1:height(landCropEconomics)
    fprintf('    %-4s | %-3s | %6d | %-4s | %6g | %5g | %s\n', ...
        landCropEconomics.('地块类型')(i), landCropEconomics.('季次')(i), ...
        landCropEconomics.('作物编号')(i), landCropEconomics.('作物名称')(i), ...
        landCropEconomics.('亩产量/斤')(i), landCropEconomics.('种植成本/(元/亩)')(i), ...
        landCropEconomics.('销售价格/(元/斤)')(i));
end

fprintf('\n==============================================================\n');
fprintf('【结果3】完整性检查\n');
fprintf('==============================================================\n');
fprintf('    Allowed=1但缺少经济参数：%d 条 %s\n', numel(miss1), iif_str(isempty(miss1)));
illegalCount = numel(illegal2) + numel(missing6) + numel(missing7);
fprintf('    非法地块类型/季次经济参数：%d 条 %s\n', illegalCount, iif_str(illegalCount==0));
fprintf('    CropID + PlotType + Season 重复冲突：%d 条 %s\n', numel(dup3)+nDupRow, ...
    iif_str(isempty(dup3) && nDupRow==0));
fprintf('    智慧大棚第一季与普通大棚第一季参数一致：%s\n', iif_str(ck4_ok));
if ck4_ok, fprintf('        %s\n', ck4_msg); end
fprintf('    检查5 经济参数作物均在crops表：%s（缺失 %d）\n', iif_str(isempty(missing5)), numel(missing5));
fprintf('    检查6 经济参数地块类型均在land表：%s（缺失 %d）\n', iif_str(isempty(missing6)), numel(missing6));
fprintf('    检查7 经济参数季次均在seasonTable：%s（缺失 %d）\n', iif_str(isempty(missing7)), numel(missing7));

% 冲突细节（如有）
allpass = isempty(miss1) && isempty(illegal2) && isempty(dup3) && nDupRow==0 && ...
          ck4_ok && isempty(missing5) && isempty(missing6) && isempty(missing7);
if ~allpass
    fprintf('\n==============================================================\n');
    fprintf('附件数据冲突/题目规则冲突\n');
    fprintf('--------------------------------------------------------------\n');
    if ~isempty(miss1)
        fprintf('  缺参数的允许组合：%s\n', strjoin(miss1, ', '));
    end
    if ~isempty(illegal2)
        fprintf('  未允许却有参数的组合：%s\n', strjoin(illegal2, ', '));
    end
    if ~isempty(dup3)
        fprintf('  重复冲突组合：%s\n', strjoin(dup3, ', '));
    end
    if nDupRow > 0
        fprintf('  同组合重复出现 %d 行\n', nDupRow);
    end
    if ~ck4_ok, fprintf('  智慧/普通大棚第一季：%s\n', ck4_msg); end
    if ~isempty(missing5), fprintf('  crops表缺失作物：%s\n', num2str(missing5)); end
    if ~isempty(missing6), fprintf('  land表缺失地块类型：%s\n', strjoin(missing6, ', ')); end
    if ~isempty(missing7), fprintf('  seasonTable缺失季次：%s\n', strjoin(missing7, ', ')); end
    fprintf('程序未修改任何数据；已停止保存步骤4结果，等待人工判断。\n');
    fprintf('==============================================================\n');
    return;
end
fprintf('\n== 结论：全部检查通过 ==\n');

%% 6. 保存结果
save('data_processed_step4.mat', ...
    'seasonCropEconomics','landCropEconomics', ...
    'stats2023_complete','land','crops','plant2023','allowedAll','seasonTable');

xlsfile = 'data_processed_step4.xlsx';
writetable(seasonCropEconomics, xlsfile, 'Sheet', '季次_农作物经济参数');
writetable(landCropEconomics,  xlsfile, 'Sheet', '地块类型_季次_农作物经济参数');
writetable(stats2023_complete, xlsfile, 'Sheet', 'stats2023_complete_原始不变');

% 检查结果 sheet
okstr = {'未通过'; '通过'};
ckItem = { 'Allowed=1但缺少经济参数', numel(miss1);
           '非法地块类型/季次经济参数', illegalCount;
           'CropID+PlotType+Season 重复冲突', numel(dup3)+nDupRow;
           '智慧大棚第一季与普通大棚第一季参数一致', double(ck4_ok);
           '经济参数作物均在crops表', numel(missing5);
           '经济参数地块类型均在land表', numel(missing6);
           '经济参数季次均在seasonTable', numel(missing7) };
ckDesc = { iif_str(isempty(miss1)); iif_str(illegalCount==0); ...
           iif_str(isempty(dup3) && nDupRow==0); ck4_msg; ...
           iif_str(isempty(missing5)); iif_str(isempty(missing6)); ...
           iif_str(isempty(missing7)) };
passFlag = [isempty(miss1), illegalCount==0, isempty(dup3)&&nDupRow==0, ck4_ok, ...
            isempty(missing5), isempty(missing6), isempty(missing7)];
Tchk = table((1:7)', ckItem(:,1), cell2mat(ckItem(:,2)), okstr(double(passFlag)+1), ckDesc);
Tchk.Properties.VariableNames = {'序号','检查项','数量','结果','说明'};
writetable(Tchk, xlsfile, 'Sheet', '数据检查结果');

fprintf('\n==============================================================\n');
fprintf('步骤4完成\n');
fprintf('==============================================================\n');
fprintf('保存：\n');
fprintf('    data_processed_step4.mat\n');
fprintf('    data_processed_step4.xlsx\n');
fprintf('      Sheet1 季次_农作物经济参数\n');
fprintf('      Sheet2 地块类型_季次_农作物经济参数\n');
fprintf('      Sheet3 stats2023_complete_原始不变\n');
fprintf('      Sheet4 数据检查结果\n');
fprintf('（销售价格均保留附件2原始区间字符串，未取平均值；\n');
fprintf('  未修改原始附件与前面步骤数据。）\n');

function s = iif_str(ok)
    if ok, s = '✓'; else, s = '✗'; end
end
