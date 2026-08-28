%% =========================================================================
%  2024年国赛C题《农作物的种植策略》 —— 数据处理阶段（第一步·修正版）
%  -------------------------------------------------------------------------
%  本脚本完成两件事：
%    任务1：读取并检查 附件1.xlsx、附件2.xlsx 的结构（不修改原始数据）
%    任务2（修正版）：智慧大棚第一季 —— 只补全“可种植关系”与“经济参数”，
%           绝不动 2023 年实际种植数据。
%
%  【修正说明】“智慧大棚第一季……与普通大棚相同”中的“相同”指的是：
%    ① 可种植的蔬菜作物集合相同；
%    ② 对应作物的亩产量相同；
%    ③ 对应作物的种植成本相同；
%    ④ 对应作物的销售价格相同。
%    并不是指“2023年智慧大棚第一季的实际种植方案”与某几个普通大棚相同。
%    因此本脚本：
%       - plant2023 保持附件2原样（尤其智慧大棚第一季 6 条记录：空心菜/黄心菜/
%         菜花/包菜/豇豆/芸豆），不删除、不替换、不修改；
%       - 不做 E1-E16 与 F1-F4 之间的任何人工映射；
%       - 只生成 allowedCropTable（可种植关系表）与 stats2023_complete（经济
%         参数表，其中智慧大棚第一季参数由普通大棚第一季按 CropID 复制）。
%
%  明确不做：
%    - 不建立优化模型 / 不调用 intlinprog / 遗传算法 / 粒子群
%    - 不做 2024-2030 优化、蒙特卡洛、敏感性分析、问题2/3
%    - 不绘制最终论文图
%    - 不生成 result1_1.xlsx / result1_2.xlsx / result2.xlsx
%
%  结果保存： data_processed_step1_corrected.mat 和 data_processed_step1_corrected.xlsx
%            （绝不会覆盖原始附件1.xlsx / 附件2.xlsx）
%
%  运行环境：MATLAB R2020a 及以上（使用 readtable / readcell / sheetnames）
% =========================================================================
clear; clc; close all;
fprintf('==============================================================\n');
fprintf('2024国赛C题 数据处理阶段（步骤1）开始\n');
fprintf('==============================================================\n');

%% ========================= 0. 文件路径配置 ==============================
file1  = '附件1.xlsx';            % 耕地与农作物信息
file2  = '附件2.xlsx';            % 2023年种植情况 + 统计参数
outMat = 'data_processed_step1_corrected.mat';
outXls = 'data_processed_step1_corrected.xlsx';

% 单个大棚面积（亩），来自附件1"乡村的现有耕地"
GREENHOUSE_AREA_MU = 0.6;

fprintf('附件路径：\n  附件1 = %s\n  附件2 = %s\n', file1, file2);

%% ========================================================================
%  任务1-A：读取并检查 附件1.xlsx
% ========================================================================
fprintf('\n########## 任务1：读取并检查附件结构 ##########\n');

% --- 1.1 附件1 的 sheet 清单 ---
sheets1 = sheetnames(file1);
fprintf('\n[附件1.xlsx] 共 %d 个 sheet：\n', numel(sheets1));
for i = 1:numel(sheets1)
    fprintf('    sheet %d：%s\n', i, sheets1(i));
end

% --- 1.2 附件1 / sheet1：乡村的现有耕地 ---
s1_name = '乡村的现有耕地';
raw_land = readcell(file1, 'Sheet', s1_name);                 % 原始读取（保留空/合并信息）
land     = readtable(file1, 'Sheet', s1_name, 'VariableNamingRule', 'preserve');
report_structure(file1, '附件1', s1_name, raw_land, land);

% --- 1.3 附件1 / sheet2：乡村种植的农作物 ---
s2_name = '乡村种植的农作物';
raw_crops = readcell(file1, 'Sheet', s2_name);
crops     = readtable(file1, 'Sheet', s2_name, 'VariableNamingRule', 'preserve');
report_structure(file1, '附件1', s2_name, raw_crops, crops);

% --- 1.4 附件1 数据规整：去掉注释行，得到干净的耕地表 / 作物表 ---
land  = clean_land_table(land);
crops = clean_crops_table(crops);

fprintf('\n[附件1] 规整后：\n');
fprintf('    耕地表 land：%d 个地块；作物表 crops：%d 种作物。\n', ...
        height(land), height(crops));

%% ========================================================================
%  任务1-B：读取并检查 附件2.xlsx
% ========================================================================
fprintf('\n----------------------------------------------\n');

% --- 1.5 附件2 的 sheet 清单 ---
sheets2 = sheetnames(file2);
fprintf('\n[附件2.xlsx] 共 %d 个 sheet：\n', numel(sheets2));
for i = 1:numel(sheets2)
    fprintf('    sheet %d：%s\n', i, sheets2(i));
end

% --- 1.6 附件2 / sheet1：2023年的农作物种植情况 ---
s3_name = '2023年的农作物种植情况';
raw_plant = readcell(file2, 'Sheet', s3_name);
plant2023 = readtable(file2, 'Sheet', s3_name, 'VariableNamingRule', 'preserve');
report_structure(file2, '附件2', s3_name, raw_plant, plant2023);

% --- 1.7 附件2 / sheet2：2023年统计的相关数据 ---
s4_name = '2023年统计的相关数据';
raw_stats = readcell(file2, 'Sheet', s4_name);
stats2023 = readtable(file2, 'Sheet', s4_name, 'VariableNamingRule', 'preserve');
report_structure(file2, '附件2', s4_name, raw_stats, stats2023);

% --- 1.8 附件2 数据规整 ---
% 1.8.1 种植情况：关键文本列转 string；合并单元格导致的空“种植地块”向下填充；
%       并根据地块名附加“地块类型”（普通大棚 / 智慧大棚 / 平旱地 / …）
plant2023 = clean_plant_table(plant2023, land);
fprintf('\n[附件2-种植情况] 规整后：%d 条记录。\n', height(plant2023));

% 1.8.2 统计参数：去掉注释行
stats2023 = clean_stats_table(stats2023);
fprintf('[附件2-统计参数] 规整后：%d 条有效记录（作物-地块类型-季次）。\n', height(stats2023));

%% ========================================================================
%  任务2：智慧大棚第一季 —— 可种植关系 与 经济参数补全
% ========================================================================
fprintf('\n==============================================================\n');
fprintf('任务2：智慧大棚第一季 可种植作物集合 与 经济参数补全\n');
fprintf('==============================================================\n');
fprintf('核心原则：“实际种植数据” 与 “可种植关系/经济参数” 严格分开。\n');
fprintf('        plant2023 一律不增、删、改；只建立可种植关系表与经济参数表。\n');

% --- 2.1 智慧大棚第一季 原始种植记录（仅展示，绝不修改）---
is_smart_g1 = (plant2023.('PlotType') == "智慧大棚") & (plant2023.('Season') == "第一季");
smG1_orig = plant2023(is_smart_g1, :);
fprintf('\n--- 【输出2】2023年智慧大棚第一季 原始种植数据（附件2原样，共 %d 条）---\n', ...
        height(smG1_orig));
disp_table_summary(smG1_orig, 20);

% --- 2.2 建立“可种植关系”（来源：附件1 作物表“种植耕地”图例）---
%  图例为合并单元格，需先向下填充。已用XML核实合并范围：
%    D2:D16  作物1-15（粮食）    -> 平旱地/梯田/山坡地（单季）
%    D17     作物16（水稻）      -> 水浇地（单季）
%    D18:D35 作物17-34（蔬菜）   -> 水浇地第一季 / 普通大棚第一季 /
%                                   智慧大棚第一季、第二季
%    D36:D38 作物35-37（大白菜等）-> 水浇地 第二季
%    D39:D42 作物38-41（食用菌） -> 普通大棚 第二季
suit_filled = filldown_col(crops, 'SuitLand');
allowedAll = build_allowed_relation(crops, suit_filled.('SuitLand'));   % 全部地块类型×季次
fprintf('\n--- 可种植关系表（来源：附件1“种植耕地”图例）---\n');
fprintf('    共 %d 条“作物×地块类型×季次”允许关系。\n', height(allowedAll));

% --- 2.3 普通大棚第一季 / 智慧大棚第一季 可种植蔬菜作物集合 ---
g1_normal_allowed = allowedAll(allowedAll.('PlotType') == "普通大棚" & ...
                               allowedAll.('Season') == "第一季", :);
g1_smart_allowed  = allowedAll(allowedAll.('PlotType') == "智慧大棚" & ...
                               allowedAll.('Season') == "第一季", :);
crops_norm = unique(g1_normal_allowed.('CropName'));
crops_smrt = unique(g1_smart_allowed.('CropName'));
fprintf('\n--- 【输出3】普通大棚第一季 可种植蔬菜作物集合（%d 种）---\n', numel(crops_norm));
fprintf('    %s\n', strjoin(crops_norm, '、'));
fprintf('--- 【输出4】智慧大棚第一季 可种植蔬菜作物集合（%d 种）---\n', numel(crops_smrt));
fprintf('    %s\n', strjoin(crops_smrt, '、'));

% --- 2.4 两个集合的差异检查 ---
fprintf('\n--- 【输出5】两个集合差异检查 ---\n');
miss_s = setdiff(crops_smrt, crops_norm);   % 智慧大棚有、普通大棚没有
miss_n = setdiff(crops_norm, crops_smrt);   % 普通大棚有、智慧大棚没有
if isempty(miss_s) && isempty(miss_n)
    fprintf('    普通大棚第一季 与 智慧大棚第一季 可种植蔬菜作物集合完全一致 ✓\n');
else
    if ~isempty(miss_n)
        fprintf('    普通大棚第一季有、智慧大棚第一季没有：%s\n', strjoin(miss_n, '、'));
    end
    if ~isempty(miss_s)
        fprintf('    智慧大棚第一季有、普通大棚第一季没有：%s\n', strjoin(miss_s, '、'));
    end
end

% --- 2.5 allowedCropTable：普通/智慧大棚 第一季 可种植关系表 ---
allowedCropTable = [g1_normal_allowed; g1_smart_allowed];
allowedCropTable = allowedCropTable(:, {'CropID', 'CropName', 'CropType', ...
                                        'PlotType', 'Season', 'Allowed'});
fprintf('\n--- allowedCropTable：%d 条（普通大棚第一季 + 智慧大棚第一季，Allowed=1 表示可种）---\n', ...
        height(allowedCropTable));
disp_table_summary(allowedCropTable, 40);

% --- 2.6 经济参数补全：stats2023_complete ---
fprintf('\n--- 智慧大棚第一季经济参数补全（来源：普通大棚第一季，按 CropID 复制）---\n');
stats2023_complete = build_stats_complete(stats2023, allowedCropTable);
smG1_param = stats2023_complete(stats2023_complete.('PlotType') == "智慧大棚" & ...
                                stats2023_complete.('Season') == "第一季", :);
fprintf('\n--- 【输出6】智慧大棚第一季 补全后的经济参数表（%d 条）---\n', height(smG1_param));
disp_table_summary(smG1_param, 30);

%% ========================================================================
%  任务2 收尾：六项自动检查
% ========================================================================
verify_corrected(file2, land, plant2023, smG1_orig, allowedCropTable, stats2023_complete);

%% ========================================================================
%  额外的数据质量初查（不修改数据，仅报告）
% ========================================================================
check_perplot_area(plant2023, land);

%% ========================================================================
%  结果保存
% ========================================================================
save(outMat, 'land', 'crops', 'plant2023', 'stats2023', 'stats2023_complete', ...
     'allowedAll', 'allowedCropTable', 'smG1_orig', ...
     'file1', 'file2', 'outMat', 'outXls');

% 写入 xlsx（多 sheet，不覆盖附件）
writetable(land,               outXls, 'Sheet', '耕地信息');
writetable(crops,              outXls, 'Sheet', '作物信息');
writetable(plant2023,          outXls, 'Sheet', '2023种植_原始未改');
writetable(stats2023_complete, outXls, 'Sheet', '2023统计参数_补全后');
writetable(allowedCropTable,   outXls, 'Sheet', '大棚一季可种植关系');
writetable(smG1_param,         outXls, 'Sheet', '智慧大棚一季参数');

fprintf('\n==============================================================\n');
fprintf('结果已保存：\n');
fprintf('    %s\n', outMat);
fprintf('    %s\n', outXls);
fprintf('（未修改原始附件1.xlsx / 附件2.xlsx）\n');
fprintf('==============================================================\n');

%% ========================================================================
%  下一步提示：后续数据处理/建模可使用的变量/文件
% ========================================================================
fprintf('\n下一步数据处理/建模可使用的变量（均在当前工作区）：\n');
fprintf('    plant2023        —— 2023实际种植表（与附件2完全一致，未做任何修改）\n');
fprintf('    land / crops     —— 地块表 / 作物表（附件1规整）\n');
fprintf('    allowedCropTable —— 普通/智慧大棚第一季 可种植关系表（Allowed=1）\n');
fprintf('    allowedAll       —— 全部“作物×地块类型×季次”可种植关系（供后续建模）\n');
fprintf('    stats2023_complete —— 经济参数表（含补全的智慧大棚第一季，共 %d 条）\n', ...
        height(stats2023_complete));
fprintf('    stats2023        —— 经济参数表（附件2原样 107 条）\n');
fprintf('    smG1_orig        —— 智慧大棚第一季原始种植记录（%d 条，未改）\n', height(smG1_orig));
fprintf('    文件              —— data_processed_step1_corrected.mat / .xlsx\n');
fprintf('\n数据处理阶段（步骤1·修正版）结束。\n');

%% ========================================================================
%  以下为局部函数
% ========================================================================

% -------------------------------------------------------------------------
function report_structure(file, filetag, sheet, raw, T)
    % 报告一个 sheet 的结构：行列数、变量名、表头、空白/合并单元格、前几行
    [nR, nC] = size(raw);
    vnames = T.Properties.VariableNames;
    fprintf('\n  --- 附件结构：%s / %s ---\n', filetag, sheet);
    fprintf('  行数 = %d（含表头），列数 = %d\n', nR, nC);
    fprintf('  MATLAB 识别的变量名（%d 个）：\n', numel(vnames));
    for k = 1:numel(vnames)
        fprintf('    %2d) %s\n', k, vnames{k});
    end
    fprintf('  原始表头：');
    for c = 1:nC
        fprintf(' [%s]', charify(raw{1, c}));
    end
    fprintf('\n');
    detect_all_empty_columns(file, sheet);
    report_blanks(raw, nR, nC);
    fprintf('  前 5 行数据：\n');
    nshow = min(5, max(0, nR - 1));
    for r = 2:(2 + nshow - 1)
        fprintf('    行%3d：', r);
        for c = 1:nC
            fprintf('[%s] ', charify(raw{r, c}));
        end
        fprintf('\n');
    end
end

% -------------------------------------------------------------------------
function detect_all_empty_columns(file, sheet)
    % 检测 sheet 的 XML 有效范围内被 readcell/readtable 自动裁掉的“全空列”。
    % 与旧版不同：先读取工作表 XML 的 dimension（真实有效范围），
    % 只报告“有效范围内”的全空列，避免把扩大读取产生的多余空列当噪音。
    % 若读取失败或不存在全空列，则静默跳过，不影响主流程。
    [nRows, nCols] = xlsx_sheet_used_size(file, sheet);
    if isnan(nRows) || isnan(nCols) || nRows < 2 || nCols < 1
        return;
    end
    try
        padded = readcell(file, 'Sheet', sheet, 'Range', excel_range_str(nRows, nCols));
        if size(padded, 1) <= 1
            return;
        end
        ism = cellfun(@isBlankCell, padded(2:end, :));
        emptyCols = find(all(ism, 1));
        if ~isempty(emptyCols)
            fprintf('  该 sheet 有效范围到第 %d 列，其中全空列（readtable 已自动忽略）：', nCols);
            for c = emptyCols
                fprintf(' 第%d列', c);
            end
            fprintf('\n');
        end
    catch
        % 读取失败时静默跳过
    end
end

% -------------------------------------------------------------------------
function [nRows, nCols] = xlsx_sheet_used_size(file, sheet)
    % 通过解析 xlsx（ZIP+XML）读取某 sheet 的 used range 尺寸。
    % 路径：unzip -> workbook.xml(sheet名→rId) -> workbook.xml.rels(rId→target)
    %     -> 工作表XML的 dimension 元素(ref="A1:XX")。
    % 用 regexp 解析（self-closing 元素），避免依赖 Java。失败时返回 NaN。
    nRows = NaN; nCols = NaN;
    tmp = tempname;
    try
        unzip(file, tmp);
        % 1) workbook.xml：sheet 名 -> rId
        wbxml = fullfile(tmp, 'xl', 'workbook.xml');
        if ~exist(wbxml, 'file'); return; end
        wb = fileread(wbxml, 'Encoding', 'UTF-8');
        rid = '';
        els = regexp(wb, '<sheet\s[^>]*/>', 'match');
        for k = 1:numel(els)
            nm = regexp(els{k}, 'name="([^"]*)"', 'tokens', 'once');
            rd = regexp(els{k}, 'r:id="([^"]*)"', 'tokens', 'once');
            if ~isempty(nm) && ~isempty(rd) && strcmp(nm{1}, sheet)
                rid = rd{1}; break;
            end
        end
        if isempty(rid); return; end
        % 2) workbook.xml.rels：rId -> 工作表xml路径
        relsxml = fullfile(tmp, 'xl', '_rels', 'workbook.xml.rels');
        if ~exist(relsxml, 'file'); return; end
        rels = fileread(relsxml, 'Encoding', 'UTF-8');
        target = '';
        relEls = regexp(rels, '<Relationship\s[^>]*/>', 'match');
        for k = 1:numel(relEls)
            id_ = regexp(relEls{k}, 'Id="([^"]*)"', 'tokens', 'once');
            tg_ = regexp(relEls{k}, 'Target="([^"]*)"', 'tokens', 'once');
            if ~isempty(id_) && ~isempty(tg_) && strcmp(id_{1}, rid)
                target = tg_{1}; break;
            end
        end
        if isempty(target); return; end
        if ~startsWith(target, 'xl/')
            target = fullfile('xl', target);
        end
        % 3) 工作表 XML：dimension（形如 <dimension ref="A1:J111"/>）
        sxml = fullfile(tmp, target);
        if ~exist(sxml, 'file'); return; end
        s = fileread(sxml, 'Encoding', 'UTF-8');
        m = regexp(s, '<dimension[^>]*ref="([^"]*)"', 'tokens', 'once');
        if isempty(m); return; end
        ref = m{1};
        toks = strsplit(ref, ':');
        mm = regexp(toks{end}, '([A-Z]+)(\d+)', 'tokens', 'once');
        if isempty(mm); return; end
        nCols = excel_col_num(mm{1});
        nRows = str2double(mm{2});
    catch
        % 失败时返回 NaN，调用方忽略
    end
    if exist(tmp, 'dir')
        try rmdir(tmp, 's'); catch; end % ok<TRYNC>
    end
end

% -------------------------------------------------------------------------
function n = excel_col_num(colstr)
    % 列字母转列号：'A'->1, 'Z'->26, 'AA'->27 ...
    n = 0;
    for i = 1:numel(colstr)
        n = n * 26 + (double(colstr(i)) - 64);
    end
end

% -------------------------------------------------------------------------
function rng = excel_range_str(nRows, nCols)
    % 由行数、列号生成 Range 字符串，如 excel_range_str(55,4) -> 'A1:D55'
    c = nCols; colstr = '';
    while c > 0
        r_ = mod(c - 1, 26);
        colstr = [char(65 + r_), colstr]; %#ok<AGROW>
        c = floor((c - 1) / 26);
    end
    rng = sprintf('A1:%s%d', colstr, nRows);
end

% -------------------------------------------------------------------------
function report_blanks(raw, nR, nC)
    % 检查数据区（第2行起）每列是否有空白，判断是否为合并单元格造成的“空洞”
    fprintf('  空白单元格检查（数据区 = 第2行之后）：\n');
    for c = 1:nC
        blanks = [];
        for r = 2:nR
            if isBlankCell(raw{r, c})
                blanks(end + 1) = r; %#ok<AGROW>
            end
        end
        if isempty(blanks)
            fprintf('    列 %d [%s]：无空白\n', c, charify(raw{1, c}));
            continue;
        end
        % 判断是否“先空后有值”（合并单元格的典型特征）
        has_hole = false;
        for r = 2:nR - 1
            if isBlankCell(raw{r, c}) && ~isBlankCell(raw{r + 1, c})
                has_hole = true; break;
            end
        end
        if has_hole
            fprintf('    列 %d [%s]：有 %d 个空白，且存在“空后又有值” → 疑似合并单元格或表格末尾的注释区，\n', ...
                c, charify(raw{1, c}), numel(blanks));
            fprintf('        （程序会按要求向下填充或单独处理，请留意）\n');
        else
            fprintf('    列 %d [%s]：有 %d 个空白（多为表尾说明文字或整列合并的注释）\n', ...
                c, charify(raw{1, c}), numel(blanks));
        end
    end
end

% -------------------------------------------------------------------------
function b = isBlankCell(x)
    % 判断一个 readcell 返回的单元格是否为“空白”
    if ismissing(x)
        b = true; return;
    end
    if ischar(x)
        b = isempty(strtrim(x)); return;
    end
    if isstring(x)
        b = (numel(x) == 1) && ismissing(x) || isempty(strtrim(char(x))); return;
    end
    b = false;
end

% -------------------------------------------------------------------------
function s = charify(x)
    % 将 readcell 单元格转为便于显示的字符
    if ismissing(x)
        s = '<空>';
    elseif ischar(x)
        s = x;
    elseif isnumeric(x)
        s = num2str(x);
    else
        s = char(string(x));
    end
    s = strtrim(s);
    if numel(s) > 40
        s = [s(1:37), '...'];
    end
end

% -------------------------------------------------------------------------
function T = ensure_string(T, colname)
    % 将表中某一列统一转为 string（便于比较与去空格）
    T.(colname) = string(strtrim(T.(colname)));
end

% -------------------------------------------------------------------------
function land = clean_land_table(land)
    % 规整“乡村的现有耕地”：列名转英文安全名（保留原列名到 Properties 中），
    % 文本转 string，面积转数值。
    land = renamevars(land, '地块名称', 'Plot');
    land = renamevars(land, '地块类型', 'PlotType');
    land = renamevars(land, '地块面积/亩', 'AreaMu');
    land = renamevars(land, '说明', 'Note');
    land = ensure_string(land, 'Plot');
    land = ensure_string(land, 'PlotType');
    land.('AreaMu') = str2double(string(land.('AreaMu')));
    % 删除全空的行（理论上无）
    land = land(~(ismissing(land.('Plot')) | strtrim(land.('Plot')) == ""), :);
end

% -------------------------------------------------------------------------
function crops = clean_crops_table(crops)
    % 规整“乡村种植的农作物”：只保留有作物编号的行（去掉末尾注释行）
    crops = renamevars(crops, '作物编号', 'CropID');
    crops = renamevars(crops, '作物名称', 'CropName');
    crops = renamevars(crops, '作物类型', 'CropType');
    crops = renamevars(crops, '种植耕地', 'SuitLand');
    crops = renamevars(crops, '说明', 'Note');
    crops = ensure_string(crops, 'CropName');
    crops = ensure_string(crops, 'CropType');
    crops = ensure_string(crops, 'SuitLand');
    crops = ensure_string(crops, 'Note');
    id = str2double(string(crops.('CropID')));
    keep = ~isnan(id);
    crops = crops(keep, :);
    crops.('CropID') = id(keep);
end

% -------------------------------------------------------------------------
function plant = clean_plant_table(plant, land)
    % 规整“2023年的农作物种植情况”：
    %  1) 重命名列为英文安全名
    %  2) 文本列转 string
    %  3) “种植地块”合并单元格造成的空白 —— 向下填充
    %  4) 依据地块名附加“地块类型”
    plant = renamevars(plant, '种植地块', 'Plot');
    plant = renamevars(plant, '作物编号', 'CropID');
    plant = renamevars(plant, '作物名称', 'CropName');
    plant = renamevars(plant, '作物类型', 'CropType');
    plant = renamevars(plant, '种植面积/亩', 'AreaMu');
    plant = renamevars(plant, '种植季次', 'Season');
    plant = ensure_string(plant, 'Plot');
    plant = ensure_string(plant, 'CropName');
    plant = ensure_string(plant, 'CropType');
    plant = ensure_string(plant, 'Season');

    % 向下填充“种植地块”（合并单元格：同地块多行记录）
    plant = filldown_col(plant, 'Plot');
    % 面积转数值
    plant.('AreaMu') = str2double(string(plant.('AreaMu')));

    % 附加地块类型
    type_map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for i = 1:height(land)
        type_map(char(land.('Plot')(i))) = char(land.('PlotType')(i));
    end
    ptype = strings(height(plant), 1);
    for i = 1:height(plant)
        p = char(plant.('Plot')(i));
        if isKey(type_map, p)
            ptype(i) = type_map(p);
        else
            ptype(i) = "未知";
        end
    end
    plant.('PlotType') = ptype;

    % 只保留有效行（地块名非空）
    plant = plant(strtrim(plant.('Plot')) ~= "", :);
end

% -------------------------------------------------------------------------
function T = filldown_col(T, colname)
    % 向下填充某列中的空白（合并单元格的常规处理）
    v = string(T.(colname));
    last = string(missing);
    for i = 1:numel(v)
        if ~ismissing(v(i)) && strtrim(v(i)) ~= ""
            last = v(i);
        else
            v(i) = last;
        end
    end
    T.(colname) = v;
end

% -------------------------------------------------------------------------
function stats = clean_stats_table(stats)
    % 规整“2023年统计的相关数据”：只保留序号为数字的行（去掉末尾注释行）
    stats = renamevars(stats, '序号', 'No');
    stats = renamevars(stats, '作物编号', 'CropID');
    stats = renamevars(stats, '作物名称', 'CropName');
    stats = renamevars(stats, '地块类型', 'LandType');
    stats = renamevars(stats, '种植季次', 'Season');
    stats = renamevars(stats, '亩产量/斤', 'YieldPerMu');
    stats = renamevars(stats, '种植成本/(元/亩)', 'CostPerMu');
    stats = renamevars(stats, '销售单价/(元/斤)', 'PricePerJin');
    stats = ensure_string(stats, 'CropName');
    stats = ensure_string(stats, 'LandType');
    stats = ensure_string(stats, 'Season');
    stats = ensure_string(stats, 'PricePerJin');
    stats.('YieldPerMu') = str2double(string(stats.('YieldPerMu')));
    stats.('CostPerMu')  = str2double(string(stats.('CostPerMu')));
    no = str2double(string(stats.('No')));
    keep = ~isnan(no);
    stats = stats(keep, :);
    stats.('No') = no(keep);
    stats.('CropID') = str2double(string(stats.('CropID')));

    % 提示：智慧大棚第一季经济参数在表中省略（与普通大棚相同）
    smg = stats(stats.('LandType') == "智慧大棚", :);
    fprintf('\n[附件2-统计参数] 智慧大棚相关记录：%d 条，季次分布：\n', height(smg));
    uniq_season = categories(categorical(string(smg.('Season'))));
    for k = 1:numel(uniq_season)
        nk = sum(string(smg.('Season')) == uniq_season(k));
        fprintf('    %s：%d 条\n', uniq_season{k}, nk);
    end
    if ~any(string(smg.('Season')) == "第一季")
        fprintf('    → 确认：智慧大棚“第一季”经济参数未列出（题注：与普通大棚相同，表中省略）。\n');
    end
end

% -------------------------------------------------------------------------
function allowed = build_allowed_relation(crops, suit_filled)
    % 由附件1“种植耕地”图例（向下填充后）构建“作物×地块类型×季次”可种植关系表。
    % 图例行格式示例：
    %   "平旱地"                       -> (平旱地, 单季)
    %   "水浇地"                       -> (水浇地, 单季)
    %   "普通大棚  第一季"             -> (普通大棚, 第一季)
    %   "智慧大棚  第一季、第二季"     -> (智慧大棚, 第一季) + (智慧大棚, 第二季)
    % 行间以换行分隔；地块类型与季次之间以空白分隔；季次以“、”分隔。
    rows = {};
    for i = 1:height(crops)
        lines = regexp(suit_filled(i), '\n+', 'split');      % 按行拆
        for li = 1:numel(lines)
            toks = strtrim(regexp(lines(li), '\s+', 'split'));
            toks = toks(toks ~= "");
            if isempty(toks)
                continue;
            end
            landType = toks(1);
            if numel(toks) >= 2
                seasons = regexp(strjoin(toks(2:end), ''), '、', 'split');
            else
                seasons = "单季";                            % 平旱地/梯田/山坡地/水稻
            end
            for si = 1:numel(seasons)
                rows(end + 1, :) = {crops.('CropID')(i), crops.('CropName')(i), ...
                                    crops.('CropType')(i), landType, seasons(si), 1}; %#ok<AGROW>
            end
        end
    end
    allowed = cell2table(rows, 'VariableNames', ...
        {'CropID', 'CropName', 'CropType', 'PlotType', 'Season', 'Allowed'});
    allowed.('CropID')   = double(allowed.('CropID'));
    allowed.('Allowed')  = double(allowed.('Allowed'));
    allowed.('CropName') = string(allowed.('CropName'));
    allowed.('CropType') = string(allowed.('CropType'));
    allowed.('PlotType') = string(allowed.('PlotType'));
    allowed.('Season')   = string(allowed.('Season'));
    % 排序：地块类型、季次、作物编号（便于查看）
    [~, ord] = sortrows(table(string(allowed.('PlotType')), ...
                              string(allowed.('Season')), allowed.('CropID')));
    allowed = allowed(ord, :);
end

% -------------------------------------------------------------------------
function stats_complete = build_stats_complete(stats2023, allowedCropTable)
    % 补全智慧大棚第一季经济参数：
    %   - 全部原有参数行（107条）原样保留，地块类型列统一命名为 PlotType；
    %   - 对 allowedCropTable 中每个“智慧大棚第一季允许种植”的作物，从
    %     “普通大棚第一季”按 CropID 复制 亩产量/种植成本/销售单价。
    %   严禁按 2023年智慧大棚实际种植记录决定补哪些作物（由 allowedCropTable 决定）。
    base = stats2023;
    base.('PlotType') = base.('LandType');
    base = base(:, {'CropID', 'CropName', 'PlotType', 'Season', ...
                    'YieldPerMu', 'CostPerMu', 'PricePerJin'});
    base.('CropName')    = strtrim(string(base.('CropName')));
    base.('PlotType')    = strtrim(string(base.('PlotType')));
    base.('Season')      = strtrim(string(base.('Season')));
    base.('PricePerJin') = strtrim(string(base.('PricePerJin')));

    % 复制源：普通大棚第一季参数表
    normG1 = base(base.('PlotType') == "普通大棚" & base.('Season') == "第一季", :);

    % 需要补参数的作物：仅取“智慧大棚第一季允许种植”的作物
    want = allowedCropTable(allowedCropTable.('PlotType') == "智慧大棚" & ...
                            allowedCropTable.('Season') == "第一季", :);
    cid = []; yld = []; cst = [];
    cname = string([]); prc = string([]);
    for i = 1:height(want)
        c = want.('CropID')(i);
        idx = find(normG1.('CropID') == c, 1);
        if isempty(idx)   % 理论上不应发生：普通大棚第一季没有该作物参数
            cid(end + 1)  = c;                    %#ok<AGROW>
            cname(end + 1) = want.('CropName')(i); %#ok<AGROW>
            yld(end + 1)  = nan;                  %#ok<AGROW>
            cst(end + 1)  = nan;                  %#ok<AGROW>
            prc(end + 1)  = string(missing);      %#ok<AGROW>
        else
            cid(end + 1)   = c;                        %#ok<AGROW>
            cname(end + 1) = normG1.('CropName')(idx); %#ok<AGROW>
            yld(end + 1)   = normG1.('YieldPerMu')(idx); %#ok<AGROW>
            cst(end + 1)   = normG1.('CostPerMu')(idx);  %#ok<AGROW>
            prc(end + 1)   = normG1.('PricePerJin')(idx); %#ok<AGROW>
        end
    end
    newT = table(cid(:), cname(:), repmat("智慧大棚", numel(cid), 1), ...
                 repmat("第一季", numel(cid), 1), yld(:), cst(:), prc(:), ...
                 'VariableNames', {'CropID', 'CropName', 'PlotType', 'Season', ...
                                   'YieldPerMu', 'CostPerMu', 'PricePerJin'});
    stats_complete = [base; newT];
    % 排序：地块类型、季次、作物编号
    [~, ord] = sortrows(table(string(stats_complete.('PlotType')), ...
                              string(stats_complete.('Season')), ...
                              stats_complete.('CropID')));
    stats_complete = stats_complete(ord, :);
end

% -------------------------------------------------------------------------
function disp_table_summary(T, maxrows)
    % 打印表内容摘要
    fprintf('    共 %d 行，列：', height(T));
    for k = 1:width(T)
        fprintf('%s ', T.Properties.VariableNames{k});
    end
    fprintf('\n');
    n = min(maxrows, height(T));
    for i = 1:n
        row_str = strings(1, width(T));
        for k = 1:width(T)
            v = T{i, k};
            if isstring(v) || ischar(v)
                row_str(k) = strtrim(string(v));
            elseif isnumeric(v)
                row_str(k) = string(num2str(v));
            else
                row_str(k) = string(v);
            end
        end
        fprintf('    %s\n', strjoin(row_str, ' | '));
    end
    if height(T) > n
        fprintf('    ……（其余 %d 行省略）\n', height(T) - n);
    end
end

% -------------------------------------------------------------------------
function verify_corrected(file2, land, plant2023, smG1_orig, ...
                          allowedCropTable, stats_complete)
    % 六项自动检查（对应题目“四、重要检查”要求）
    fprintf('\n========== 六项自动检查 ==========\n');
    all_ok = true;

    % --- 检查1：智慧大棚第一季 原始记录数量保持不变 ---
    fprintf('1) 智慧大棚第一季原始记录数量检查：\n');
    n_orig = sum(plant2023.('PlotType') == "智慧大棚" & ...
                 plant2023.('Season') == "第一季");
    fprintf('    plant2023 中智慧大棚第一季记录数 = %d（附件2原样应为 6）\n', n_orig);
    if n_orig ~= 6
        fprintf('    ✗ 数量异常！\n');
        all_ok = false;
    else
        fprintf('    ✓ 数量保持不变（6 条，未删除未替换）\n');
    end

    % --- 检查2：智慧大棚第一季 具体记录保持不变（重新读取附件2逐条对比）---
    fprintf('2) 智慧大棚第一季具体记录不变（重新读取附件2对比）：\n');
    re_T = readtable(file2, 'Sheet', '2023年的农作物种植情况', 'VariableNamingRule', 'preserve');
    re_plant = clean_plant_table(re_T, land);
    re_smg1 = re_plant(re_plant.('PlotType') == "智慧大棚" & ...
                       re_plant.('Season') == "第一季", :);
    k1 = sortrows(smG1_orig(:, {'Plot', 'CropID', 'CropName', 'AreaMu', 'Season'}));
    k2 = sortrows(re_smg1(:, {'Plot', 'CropID', 'CropName', 'AreaMu', 'Season'}));
    if isequal(k1, k2)
        fprintf('    ✓ 与附件2原文件逐条一致（共 %d 条，未增删改）\n', height(k1));
    else
        fprintf('    ✗ 与附件2原文件不一致！\n');
        all_ok = false;
    end

    % --- 检查3：普通大棚第一季 与 智慧大棚第一季 可种植集合完全一致 ---
    fprintf('3) 普通大棚第一季 与 智慧大棚第一季 可种植蔬菜作物集合一致性：\n');
    nset = unique(allowedCropTable.('CropName')(allowedCropTable.('PlotType') == "普通大棚" & ...
                                                allowedCropTable.('Season') == "第一季"));
    sset = unique(allowedCropTable.('CropName')(allowedCropTable.('PlotType') == "智慧大棚" & ...
                                                allowedCropTable.('Season') == "第一季"));
    miss_s = setdiff(sset, nset);
    miss_n = setdiff(nset, sset);
    if isempty(miss_s) && isempty(miss_n)
        fprintf('    ✓ 两个集合完全一致（各 %d 种）\n', numel(nset));
    else
        fprintf('    ✗ 两个集合不一致！\n');
        all_ok = false;
        if ~isempty(miss_n)
            fprintf('      普通大棚有而智慧大棚没有：%s\n', strjoin(miss_n, '、'));
        end
        if ~isempty(miss_s)
            fprintf('      智慧大棚有而普通大棚没有：%s\n', strjoin(miss_s, '、'));
        end
    end

    % --- 检查4：智慧大棚第一季补全参数 与 普通大棚第一季 逐作物一致 ---
    fprintf('4) 智慧大棚第一季补全参数 与 普通大棚第一季 逐作物一致性：\n');
    sm = stats_complete(stats_complete.('PlotType') == "智慧大棚" & ...
                        stats_complete.('Season') == "第一季", :);
    nm = stats_complete(stats_complete.('PlotType') == "普通大棚" & ...
                        stats_complete.('Season') == "第一季", :);
    ok4 = true;
    for i = 1:height(sm)
        idx = find(nm.('CropID') == sm.('CropID')(i), 1);
        if isempty(idx) || sm.('YieldPerMu')(i) ~= nm.('YieldPerMu')(idx) || ...
           sm.('CostPerMu')(i) ~= nm.('CostPerMu')(idx) || ...
           sm.('PricePerJin')(i) ~= nm.('PricePerJin')(idx)
            ok4 = false;
        end
    end
    if ok4
        fprintf('    ✓ 全部 %d 种作物 亩产量/种植成本/销售价格 与普通大棚第一季逐项一致\n', height(sm));
    else
        fprintf('    ✗ 存在不一致参数\n');
        all_ok = false;
    end

    % --- 检查5：普通大棚第一季允许种植、但智慧大棚第一季没补上参数 ---
    fprintf('5) 普通大棚第一季允许种植、但智慧大棚第一季没有成功补全参数的作物：\n');
    allowed_n = unique(allowedCropTable.('CropID')(allowedCropTable.('PlotType') == "普通大棚" & ...
                                                   allowedCropTable.('Season') == "第一季"));
    sm_params = unique(sm.('CropID'));
    missing5 = setdiff(allowed_n, sm_params);
    if isempty(missing5)
        fprintf('    ✓ 无遗漏（全部 %d 种允许作物均已成功补全参数）\n', numel(allowed_n));
    else
        fprintf('    ✗ 存在遗漏：作物编号 %s\n', strjoin(string(missing5), '、'));
        all_ok = false;
    end

    % --- 检查6：智慧大棚第一季出现参数、但普通大棚第一季不存在对应参数 ---
    fprintf('6) 智慧大棚第一季出现参数、但普通大棚第一季不存在对应参数的作物：\n');
    nm_params = unique(nm.('CropID'));
    phantom = setdiff(sm_params, nm_params);
    if isempty(phantom)
        fprintf('    ✓ 无越界参数（智慧大棚第一季每个参数都来自普通大棚第一季）\n');
    else
        fprintf('    ✗ 存在越界参数：作物编号 %s\n', strjoin(string(phantom), '、'));
        all_ok = false;
    end

    if all_ok
        fprintf('\n== 验证结论：六项自动检查全部通过 ✓ ==\n');
        fprintf('   2023实际种植数据未做任何修改；可种植关系与经济参数补全正确。\n');
    else
        fprintf('\n== 验证结论：存在需人工确认/处理的项目，见上方 ✗ ==\n');
    end
end

% -------------------------------------------------------------------------
function check_perplot_area(plant2023, land)
    % 数据质量初查：每个地块每个季次的种植面积之和 是否等于该地块面积
    % （智慧大棚/普通大棚按单季0.6亩计，期望面积直接来自附件1耕地表）
    fprintf('\n========== 数据质量初查：单季面积之和 vs 地块面积 ==========\n');
    plots = unique(plant2023.('Plot'));
    n_bad = 0;
    for i = 1:numel(plots)
        p = plots(i);
        sub = plant2023(strtrim(plant2023.('Plot')) == p, :);
        seasons = unique(sub.('Season'));
        for s = 1:numel(seasons)
            a_sum = sum(sub.('AreaMu')(string(sub.('Season')) == seasons(s)));
            % 期望面积：查附件1
            expect = find_area_of_plot(land, p);
            if isnan(expect)
                continue;
            end
            if abs(a_sum - expect) > 1e-6
                n_bad = n_bad + 1;
                fprintf('    异常：地块 %s，季次 %s，种植面积和 = %.1f，地块面积 = %.1f ✗\n', ...
                        p, seasons(s), a_sum, expect);
            end
        end
    end
    if n_bad == 0
        fprintf('    全部地块 × 季次的面积和与地块面积一致 ✓\n');
    else
        fprintf('    共发现 %d 处不一致（请人工核对）。\n', n_bad);
    end
end

% -------------------------------------------------------------------------
function a = find_area_of_plot(land, plotname)
    % 从附件1耕地表查找某地块的面积（亩）；找不到返回 NaN
    idx = find(strtrim(land.('Plot')) == plotname, 1);
    if isempty(idx)
        a = NaN;
    else
        a = land.('AreaMu')(idx);
    end
end
