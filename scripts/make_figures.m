function make_figures(root)
%MAKE_FIGURES  Draw the model figures of the thesis (Figures 3 to 8) from output/results.mat.
%   PNG files go to figures/, vector PDFs (used in the thesis) to output/pdf/.
%
%   Fig. 3  damage specifications as functions of warming (formulas, no simulation)
%   Fig. 4  macro-financial effects of the five policies, 1.5 degree world, no damage
%   Fig. 5  annual default probability, same runs
%   Fig. 6  the five policies in the 1.5 and 3 degree worlds, no damage
%   Fig. 7  output, debt and default under each damage specification, 1.5 degree world
%   Fig. 8  output under each damage specification, carbon tax, 3 degree world

    S = load(fullfile(root, 'output', 'results.mat'));
    RES = S.RES;
    L = plot_lib();
    O = L.options();
    O.outdir = fullfile(root, 'figures');
    O.pdfdir = fullfile(root, 'output', 'pdf');
    ST = plot_style();

    fprintf('Figures:\n');
    fig3_damage_shapes(L, O, ST);
    fig4_macro_financial(RES, L, O, ST);
    fig5_default_probability(RES, L, O, ST);
    fig6_policy_two_worlds(RES, L, O, ST);
    fig_damage_zoom(RES, L, O, ST, 1, {'y', 'b', 'pd'}, 'fig7_damage_zoom_1p5C');
    fig8_damage_gdp_3C(RES, L, O, ST);
end


% =====================================================================================
%  Settings shared by the figures
% =====================================================================================

function y0 = start_year();  y0 = 2024;  end

function T = window(world)
% Quarters displayed: the 35 years of the paper in the 1.5 degree world, 125 years in the
% 3 degree world, whose carbon budget is spent much later. Both are solved far beyond.
    if world == 1;  T = 140;  else;  T = 500;  end
end

function z = transform(r, name, cols)
% Units used on every plot: real quantities as a ratio to their value in the first
% simulated quarter, the default probability and the bond rate annualised in per cent.
    z = series_of(r, name, cols);
    switch name
        case {'y', 'c', 'i_inv', 'e'};  z = z / z(1);
        case 'pd';                      z = 100 * (1 - (1 - z).^4);
        case 'rd';                      z = 100 * (z.^4 - 1);
    end
end

function B = scenario_legend(L, ST, tagged)
    E = [];
    for s = 1:5
        q = ST.scenario{s};
        nm = q.name;
        if tagged;  nm = sprintf('%s  %s', q.id, q.name);  end
        E = L.entry(E, nm, q.col, q.ls, 'mk', q.mk);
    end
    ttl = 'Policy scenario';
    if tagged;  ttl = 'Transition scenario';  end
    B = L.block([], ttl, E);
end

function B = damage_legend(L, ST)
    E = [];
    for q = ST.damage
        E = L.entry(E, q.name, q.col, q.ls, 'lw', 1.3);
    end
    B = L.block([], 'Damage specification', E);
end


% =====================================================================================
%  Figure 3: the damage specifications
% =====================================================================================

function fig3_damage_shapes(L, O, ST)
% Drawn from the formulas of the model file, normalised to zero at the start-date warming
% of 1.4 degrees. Left: log productivity. Right: long-run share of output lost, once the
% capital stock has adjusted (exponent 1/(1-kappa)). The two-kernel specification is drawn
% at its long-run limit exp(a T), a = A (1/B - 1/C).
    kappa = 0.33;  T0 = 1.4;
    T = linspace(T0, 4.5, 220);
    a_BK = -7.0217 * (1/0.5784 - 1/0.5870);
    lnDf = { log((1 - 0.003467*T.^2) / (1 - 0.003467*T0^2)), ...        % DICE-2023
             log((1 - 0.0335*T - 0.0009*T.^2) / (1 - 0.0335*T0 - 0.0009*T0^2)), ...
             -0.02/2 * (T.^2 - T0^2), ...                                % Seghini and Dees
             -0.08/2 * (T.^2 - T0^2), ...                                % Seghini, Dees, De Gaye
             a_BK * (T - T0) };                                          % Bilal and Kanzig
    loss = cellfun(@(v) 1 - exp(v / (1 - kappa)), lnDf, 'UniformOutput', false);

    D = ST.damage(2:end);
    E = [];
    for q = D;  E = L.entry(E, q.name, q.col, q.ls);  end
    B = L.block([], 'Damage specification', E);

    xl = 'Warming above pre-industrial, °C';
    P = L.panel([], '(a) Productivity', 'ln Df vs. start', ...
                @(ax) draw_curves(ax, T, lnDf, D), 'xlab', xl);
    P = L.panel(P, '(b) Output', 'share of output lost vs. start', ...
                @(ax) draw_curves(ax, T, loss, D), 'xlab', xl);
    L.plate(P, B, 1, 2, 'fig3_damage_shapes', O);
end

function draw_curves(ax, T, Y, D)
    for k = 1:numel(D)
        plot(ax, T, Y{k}, D(k).ls, 'Color', D(k).col, 'LineWidth', 1.6);
    end
    yline(ax, 0, 'k:', 'HandleVisibility', 'off');
    xlim(ax, [T(1), T(end)]);
end


% =====================================================================================
%  Figures 4 and 5: the five policies, 1.5 degree world, no damage
% =====================================================================================

function fig4_macro_financial(RES, L, O, ST)
    T = window(1);  cols = 2:T+1;
    years = start_year() + (0:T-1)/4;
    runs = arrayfun(@(s) pick_run(RES, s, 0, 1), 1:5, 'UniformOutput', false);

    % The carbon price is a detrended ratio without a monetary unit. It is rescaled so that
    % the carbon-tax scenario ends the window at 1000 dollars per tonne, as in the paper.
    scale = 1000 / series_of(runs{1}, 'pe', T+1);

    titles = {'Carbon tax', 'GDP', 'Public debt', 'Interest rate on public debt', ...
              'Consumption', 'Investment'};
    ylabs  = {'USD per tCO2', 'ratio to start', 'debt to GDP', ...
              'annual, %', 'ratio to start', 'ratio to start'};
    P = [];
    for p = 1:6
        P = L.panel(P, titles{p}, ylabs{p}, ...
                    @(ax) draw_macro(ax, runs, ST, L, years, cols, p, scale, T));
    end
    O.rowHeight = 5.33;
    L.plate(P, scenario_legend(L, ST, true), 3, 2, 'fig4_macro_financial', O);
end

function draw_macro(ax, runs, ST, L, years, cols, p, scale, T)
    for s = 1:5
        r = runs{s};
        if isempty(r);  continue;  end
        switch p
            case 1;  z = series_of(r, 'pe', cols) * scale;
            case 2;  z = series_of(r, 'y', cols) / series_of(r, 'y', 1);
            case 3;  z = series_of(r, 'b', cols);
            case 4   % annualised, averaged over the trailing four quarters
                raw = (series_of(r, 'rd', 1:T+1).^4 - 1) * 100;
                z = movmean(raw, [3 0]);  z = z(2:end);
            case 5;  z = series_of(r, 'c', cols) / series_of(r, 'c', 1);
            case 6;  z = series_of(r, 'i_inv', cols) / series_of(r, 'i_inv', 1);
        end
        L.series(ax, years, z, ST.scenario{s});
    end
    xlim(ax, [years(1), years(1) + numel(years)/4]);
end

function fig5_default_probability(RES, L, O, ST)
    T = window(1);  cols = 2:T+1;
    years = start_year() + (0:T-1)/4;
    runs = arrayfun(@(s) pick_run(RES, s, 0, 1), 1:5, 'UniformOutput', false);
    P = L.panel([], 'Default probability', 'annual, %', ...
                @(ax) draw_default(ax, runs, ST, L, years, cols));
    L.plate(P, scenario_legend(L, ST, false), 1, 1, 'fig5_default_probability', O);
end

function draw_default(ax, runs, ST, L, years, cols)
    for s = 1:5
        if isempty(runs{s});  continue;  end
        L.series(ax, years, 100 * (1 - (1 - series_of(runs{s}, 'pd', cols)).^4), ST.scenario{s});
    end
    xlim(ax, [years(1), years(1) + numel(years)/4]);
end


% =====================================================================================
%  Figure 6: the five policies in both worlds, no damage
% =====================================================================================

function fig6_policy_two_worlds(RES, L, O, ST)
% Both columns span the same 125 years so that each row compares on one scale.
    T = window(2);
    vars  = {'y', 'c', 'i_inv', 'b', 'pd'};
    names = {'output, ratio to start', 'consumption, ratio to start', ...
             'investment, ratio to start', 'public debt, debt to GDP', ...
             'default probability, % a year'};
    heads = world_names(RES);
    P = [];
    for v = 1:numel(vars)
        for w = 1:2
            head = '';  if v == 1;  head = heads{w};  end
            lab  = '';  if w == 1;  lab  = names{v};  end
            P = L.panel(P, head, lab, @(ax) draw_policies(ax, RES, ST, vars{v}, w, T), ...
                        'row', vars{v});
        end
    end
    O.rowHeight = 2.70;
    O.shareRows = true;
    L.plate(P, scenario_legend(L, ST, false), numel(vars), 2, 'fig6_policy_two_worlds', O);
end

function draw_policies(ax, RES, ST, name, world, T)
    for s = 1:5
        r = pick_run(RES, s, 0, world);
        if isempty(r);  continue;  end
        z = transform(r, name, 2:T+1);
        x = start_year() + (0:numel(z)-1)/4;
        q = ST.scenario{s};
        plot(ax, x, z, q.ls, 'Color', q.col, 'LineWidth', 1.4, 'Marker', q.mk, ...
             'MarkerIndices', 1:max(1, round(numel(z)/6)):numel(z), 'MarkerSize', 3, ...
             'MarkerFaceColor', q.col);
    end
    xlim(ax, start_year() + [0, T/4]);
end

function heads = world_names(RES)
% Column titles, with the warming reached read off the no-damage carbon-tax runs.
    T1 = max(series_of(pick_run(RES, 1, 0, 1), 'That', ':'));
    T2 = max(series_of(pick_run(RES, 1, 0, 2), 'That', ':'));
    heads = {sprintf('240 GtCO2 budget, %.2f °C', T1), ...
             sprintf('3055 GtCO2 budget, %.2f °C', T2)};
end


% =====================================================================================
%  Figures 7 and 8: every damage specification, one column per policy
% =====================================================================================

function fig_damage_zoom(RES, L, O, ST, world, vars, file)
    T = window(world);
    names = struct('y', 'output, ratio to start', 'c', 'consumption, ratio to start', ...
                   'i_inv', 'investment, ratio to start', 'b', 'public debt, debt to GDP', ...
                   'pd', 'default probability, % a year');
    P = [];
    for v = 1:numel(vars)
        for s = 1:5
            head = '';  if v == 1;  head = ST.scenario{s}.short;  end
            lab  = '';  if s == 1;  lab  = names.(vars{v});  end
            P = L.panel(P, head, lab, @(ax) draw_damages(ax, RES, ST, vars{v}, s, world, T), ...
                        'row', vars{v});
        end
    end
    O.rowHeight = 3.6;
    O.shareRows = true;
    L.plate(P, damage_legend(L, ST), numel(vars), 5, file, O);
end

function fig8_damage_gdp_3C(RES, L, O, ST)
% One panel: the other policies, and consumption and investment, show the same pattern.
    T = window(2);
    P = L.panel([], 'GDP, carbon tax scenario', 'ratio to start', ...
                @(ax) draw_damages(ax, RES, ST, 'y', 1, 2, T));
    L.plate(P, damage_legend(L, ST), 1, 1, 'fig8_damage_gdp_3C', O);
end

function draw_damages(ax, RES, ST, name, scenario, world, T)
    for q = ST.damage
        r = pick_run(RES, scenario, q.flag, world);
        if isempty(r);  continue;  end
        z = transform(r, name, 2:T+1);
        x = start_year() + (0:numel(z)-1)/4;
        plot(ax, x, z, q.ls, 'Color', q.col, 'LineWidth', 1.3);
    end
    xlim(ax, start_year() + [0, T/4]);
end
