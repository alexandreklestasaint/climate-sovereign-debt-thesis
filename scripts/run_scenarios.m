function RES = run_scenarios(root)
%RUN_SCENARIOS  Solve the model for every policy scenario, damage specification and world.
%   RES = run_scenarios(root) runs model/sd24_climate_debt.mod with Dynare for
%   5 scenarios x 6 damage settings x 2 carbon budgets (60 runs) and saves the paths to
%   output/results.mat under the repository root.
%
%   Each element of RES holds the configuration, whether the solver converged, and the
%   simulated paths: column 1 of RES(n).sim is the brown economy (initial condition), the
%   last column the green steady state.

    global M_ oo_ %#ok<GVMIS>

    modeldir = fullfile(root, 'model');
    outdir   = fullfile(root, 'output');
    if ~isfolder(outdir);  mkdir(outdir);  end

    [S, D, W] = ndgrid(1:5, 0:5, 1:2);
    cfg = [S(:), D(:), W(:)];
    cfg = sortrows(cfg, [3 2 1]);
    n   = size(cfg, 1);

    here = pwd;
    cleanup = onCleanup(@() cd(here));
    cd(modeldir);

    RES = struct('scenario', {}, 'damage', {}, 'world', {}, 'usable', {}, ...
                 'endo_names', {}, 'sim', {});
    for j = 1:n
        s = cfg(j,1);  d = cfg(j,2);  w = cfg(j,3);
        fprintf('\n=== run %d of %d: scenario %d, damage %d, world %d ===\n', j, n, s, d, w);
        ok = false;
        try
            dynare('sd24_climate_debt.mod', sprintf('-Dscenario=%d', s), ...
                   sprintf('-Ddamage=%d', d), sprintf('-Dworld=%d', w), ...
                   'nograph', 'nolog', 'noclearall');
            ok = oo_.deterministic_simulation.status == 1;
        catch err
            fprintf('  failed: %s\n', err.message);
        end
        RES(j).scenario = s;
        RES(j).damage   = d;
        RES(j).world    = w;
        RES(j).usable   = ok;
        if ok
            RES(j).endo_names = cellstr(M_.endo_names);
            RES(j).sim        = oo_.endo_simul;
        else
            warning('run_scenarios:noSolution', ...
                    'No solution for scenario %d, damage %d, world %d.', s, d, w);
        end
    end

    save(fullfile(outdir, 'results.mat'), 'RES');
    fprintf('\n%d of %d runs solved. Results in output/results.mat\n', sum([RES.usable]), n);
end
