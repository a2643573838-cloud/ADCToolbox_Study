% Add the repository to the MATLAB path and persist it for future sessions.
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(repoRoot, 'startup.m'));
savepath;
