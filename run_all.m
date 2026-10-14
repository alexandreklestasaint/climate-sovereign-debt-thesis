% RUN_ALL  Reproduce the model results and figures of the thesis.
%
%   Solves the 60 configurations (5 policy scenarios x 6 damage settings x 2 carbon
%   budgets) with Dynare, saves the paths to output/results.mat, draws Figures 3 to 8
%   into figures/ and prints the headline numbers of every run.
%
%   Requirements: MATLAB (tested on R2025b) and Dynare 7.1 on the MATLAB path, e.g.
%       addpath('C:\dynare\7.1\matlab')
%   Running time: about half an hour on a laptop.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'scripts'));
if isempty(which('dynare'))
    error('run_all:dynare', 'Dynare is not on the MATLAB path. Add its matlab/ folder first.');
end

RES = run_scenarios(root);
make_figures(root);
summarize_runs(RES);
