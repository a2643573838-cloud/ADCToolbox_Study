%% run_plotspec_examples
% Self-contained examples for the copied plotspec.m and alias.m files.
% Run this script from MATLAB after cd'ing into plotspec_study_pack, or run
% it by full path from any folder.

clear;
close all;
clc;

scriptDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(scriptDir, 'data');
addpath(scriptDir);

requiredFiles = {
    fullfile(scriptDir, 'plotspec.m')
    fullfile(scriptDir, 'alias.m')
    fullfile(dataDir, 'coherent_10bit_sine.csv')
    fullfile(dataDir, 'leaky_10bit_sine.csv')
    fullfile(dataDir, 'multirun_10bit_sine.csv')
    fullfile(dataDir, 'osr_noise_shaped_like.csv')
};

for k = 1:numel(requiredFiles)
    if ~isfile(requiredFiles{k})
        error('plotspecStudy:missingFile', 'Missing required file: %s', requiredFiles{k});
    end
end

Fs = 1e6;
nbits = 10;
maxCode = 2^nbits;
harmonic = 5;

%%
fprintf('Example 0: alias dependency check\n');
disp(table([30; 70; 130], alias([30; 70; 130], 100), ...
    'VariableNames', {'InputFrequency', 'AliasedFrequency'}));
%%
fprintf('\nExample 1: coherent 10-bit sine, Hann window\n');
sig = readmatrix(fullfile(dataDir, 'coherent_10bit_sine.csv'));
figure('Name', 'Coherent 10-bit sine, Hann window');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sig, Fs, maxCode, harmonic, ...
    'window', 'hann', 'sideBin', 'auto','NFMethod', 'exclude');
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
fprintf('\nExample 2: same coherent sine, rectangle window\n');
figure('Name', 'Coherent 10-bit sine, rectangle window');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sig, Fs, maxCode, harmonic, ...
    'window', 'rect', 'sideBin', 0,'NFMethod', 'exclude');
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
fprintf('\nExample 3: off-bin sine, observe spectral leakage\n');
sigLeak = readmatrix(fullfile(dataDir, 'leaky_10bit_sine.csv'));
figure('Name', 'Leaky 10-bit sine');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sigLeak, Fs, maxCode, harmonic, ...
    'window', 'hann', 'sideBin', 'auto', 'NFMethod', 'mean');
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
fprintf('\nExample 4: multi-run data, coherent averaging\n');
sigMulti = readmatrix(fullfile(dataDir, 'multirun_10bit_sine.csv'));
figure('Name', 'Multi-run coherent averaging');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sigMulti, Fs, maxCode, harmonic, ...
    'window', 'hann', 'averageMode', 'coherent', 'sideBin', 'auto');
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
fprintf('\nExample 5: OSR analysis with shaped-noise-like data\n');
sigOsr = readmatrix(fullfile(dataDir, 'osr_noise_shaped_like.csv'));
figure('Name', 'OSR noise-shaped-like example');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sigOsr, Fs, maxCode, harmonic, ...
    'window', 'hann', 'OSR', 16, 'sideBin', 'auto', 'NFMethod', 'median');
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
fprintf('\nExample 6: numeric-only call without plotting\n');
[enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd] = plotspec(sig, Fs, maxCode, harmonic, ...
    'disp', false);
printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd);
%%
function printMetrics(enob, sndr, sfdr, snr, thd, sigpwr, noi, nsd)
    fprintf('  ENOB   = %8.3f bits\n', enob);
    fprintf('  SNDR   = %8.3f dB\n', sndr);
    fprintf('  SFDR   = %8.3f dB\n', sfdr);
    fprintf('  SNR    = %8.3f dB\n', snr);
    fprintf('  THD    = %8.3f dB\n', thd);
    fprintf('  SigPwr = %8.3f dBFS\n', sigpwr);
    fprintf('  NF     = %8.3f dB\n', noi);
    fprintf('  NSD    = %8.3f dBFS/Hz\n', nsd);
end
