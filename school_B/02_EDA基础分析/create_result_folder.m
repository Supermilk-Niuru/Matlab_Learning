function [overallDir, singleDir, numericDir] = create_result_folder()
% CREATE_RESULT_FOLDER 创建三个结果文件夹
%   - 整体流失分析
%   - 单因素流失分析
%   - 连续因素分析
%   文件夹不存在时自动使用 mkdir 创建。
%
%   输出：
%     overallDir —— 整体流失分析文件夹完整路径
%     singleDir  —— 单因素流失分析文件夹完整路径
%     numericDir —— 连续因素分析文件夹完整路径

overallDir = fullfile(pwd, '整体流失分析');
singleDir  = fullfile(pwd, '单因素流失分析');
numericDir = fullfile(pwd, '连续因素分析');

% 不存在则创建
if ~isfolder(overallDir)
    mkdir(overallDir);
end
if ~isfolder(singleDir)
    mkdir(singleDir);
end
if ~isfolder(numericDir)
    mkdir(numericDir);
end

fprintf('-------- 结果文件夹准备 --------\n');
fprintf('  整体流失分析：%s\n', overallDir);
fprintf('  单因素流失分析：%s\n', singleDir);
fprintf('  连续因素分析：%s\n', numericDir);
fprintf('\n');

end
