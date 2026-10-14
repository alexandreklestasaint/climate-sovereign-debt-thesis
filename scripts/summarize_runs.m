function T = summarize_runs(RES)
%SUMMARIZE_RUNS  Headline numbers of every run, read over the displayed window.
%   T = summarize_runs(RES) returns and prints a table with, for each run:
%     debt_peak     highest public debt to GDP
%     pd_peak       highest annual default probability, per cent
%     gdp_end       output at the end of the window, per cent deviation from the first quarter
%     gdp_vs_nodmg  output at the end of the window, per cent deviation from the no-damage
%                   run of the same scenario and world
%     warming_max   highest warming reached, degrees above pre-industrial

    rows = {};
    for r = RES(:)'
        if ~r.usable;  continue;  end
        W = 140;  if r.world == 2;  W = 500;  end
        cols = 2:W+1;
        y  = series_of(r, 'y', cols);
        b  = series_of(r, 'b', cols);
        pd = 100 * (1 - (1 - series_of(r, 'pd', cols)).^4);
        r0 = pick_run(RES, r.scenario, 0, r.world);
        rel = NaN;
        if ~isempty(r0);  rel = 100 * (y(end) / series_of(r0, 'y', W+1) - 1);  end
        rows(end+1, :) = {r.world, r.scenario, r.damage, max(b), max(pd), ...
                          100 * (y(end)/y(1) - 1), rel, max(series_of(r, 'That', ':'))}; %#ok<AGROW>
    end
    T = cell2table(rows, 'VariableNames', {'world', 'scenario', 'damage', 'debt_peak', ...
                   'pd_peak', 'gdp_end', 'gdp_vs_nodmg', 'warming_max'});
    disp(T);
end
