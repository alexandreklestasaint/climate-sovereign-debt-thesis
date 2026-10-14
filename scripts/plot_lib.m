function L = plot_lib()
%PLOT_LIB  Layout and export helpers shared by the figure scripts.
%   A figure is a "plate": a grid of panels, each described by a title, a y-label and a
%   drawing function, with a legend set below the grid. Plates are 16 cm wide, the text
%   width of the thesis, and are exported as PNG (300 dpi) and vector PDF.
%
%   L = plot_lib() returns a struct of function handles:
%       L.options()                     default layout options
%       L.panel(P, title, ylab, drawfn, 'xlab', ..., 'row', ...)
%       L.entry(E, name, colour, linestyle, 'mk', ..., 'lw', ...)
%       L.block(B, title, entries)      a titled legend block
%       L.plate(P, B, rows, cols, file, opt)
%       L.series(ax, x, y, style)       one scenario curve with sparse markers
%       L.band(ax, x, lo, hi, colour, alpha)

    L.options = @options;
    L.panel   = @panel;
    L.entry   = @entry;
    L.block   = @block;
    L.plate   = @plate;
    L.series  = @series;
    L.band    = @band;
end


function O = options()
    O.width     = 16.0;     % cm
    O.rowHeight = 5.33;     % cm per row of panels
    O.head      = 0.85;     % cm above the grid
    O.inset     = 0.30;
    O.fsPanel   = 8;
    O.fsLegend  = 8;
    O.shareRows = false;    % common y-scale along each row
    O.outdir    = 'figures';
    O.pdfdir    = '';       % if set, the vector PDF goes there
    O.font      = document_font();
end


function P = panel(P, ttl, ylab, drawfn, varargin)
    q = struct('title', ttl, 'ylab', ylab, 'draw', drawfn, 'xlab', 'Year', 'row', '');
    for k = 1:2:numel(varargin);  q.(varargin{k}) = varargin{k+1};  end
    if isempty(P);  P = q;  else;  P(end+1) = q;  end
end


function E = entry(E, nm, col, ls, varargin)
    q = struct('name', nm, 'col', col, 'ls', ls, 'lw', 1.6, 'mk', 'none');
    for k = 1:2:numel(varargin);  q.(varargin{k}) = varargin{k+1};  end
    if isempty(E);  E = q;  else;  E(end+1) = q;  end
end


function B = block(B, ttl, entries)
    q = struct('title', ttl, 'entries', entries);
    if isempty(B);  B = {q};  else;  B{end+1} = q;  end
end


function series(ax, x, y, st)
    mi = round(linspace(1, numel(x), 7));
    plot(ax, x, y, 'Color', st.col, 'LineStyle', st.ls, 'LineWidth', 1.4, ...
         'Marker', st.mk, 'MarkerIndices', mi, 'MarkerSize', 3.0, ...
         'MarkerFaceColor', st.col, 'HandleVisibility', 'off');
end


function band(ax, x, lo, hi, col, alpha)
    fill(ax, [x(:); flipud(x(:))], [lo(:); flipud(hi(:))], col, ...
         'FaceAlpha', alpha, 'EdgeColor', 'none', 'HandleVisibility', 'off');
end


function plate(P, B, rows, cols, file, O)
    footer = footer_height(B, O);
    H  = O.head + rows * O.rowHeight + footer;
    if rows == 1;  H = max(H, 10.0);  end

    % Wrap panel titles and y-labels to the space they have.
    TW = O.width / cols - 0.55;
    LH = (H - footer) / rows - 1.9;
    TT = cell(1, numel(P));  YL = cell(1, numel(P));  nt = 1;
    for k = 1:numel(P)
        TT{k} = wrap(P(k).title, TW, O.fsPanel + 1, 2);
        YL{k} = wrap(P(k).ylab,  LH, O.fsPanel,     2);
        nt    = max(nt, numel(TT{k}));
    end
    H = H + (nt - 1) * 0.75 * rows;
    spacing = 'compact';
    if nt > 1;  spacing = 'loose';  end
    stacked = any(arrayfun(@(k) ~isempty(P(k).xlab), 1:max(0, numel(P) - cols)));
    if stacked && rows > 1
        spacing = 'loose';
        H = H + 0.55 * (rows - 1);
    end

    fig = figure('Units', 'centimeters', 'Position', [1 1 O.width H], ...
                 'Color', 'w', 'Visible', 'off');
    set(fig, 'DefaultAxesFontName', O.font, 'DefaultTextFontName', O.font);
    tl = tiledlayout(fig, rows, cols, 'Padding', 'compact', 'TileSpacing', spacing);
    tl.Units = 'centimeters';
    tl.OuterPosition = [O.inset, footer, O.width - O.inset, H - footer];

    AX = gobjects(1, numel(P));
    for k = 1:numel(P)
        ax = nexttile(tl);  hold(ax, 'on');  AX(k) = ax;
        style_axes(ax, O);
        P(k).draw(ax);
        t = title(ax, TT{k}, 'FontSize', O.fsPanel + 1, 'FontWeight', 'bold', ...
                  'Color', 'k', 'Interpreter', 'none');
        t.Units = 'normalized';  t.VerticalAlignment = 'bottom';  t.Position(2) = 1.0;
        if ~isempty(P(k).ylab)
            ylabel(ax, YL{k}, 'FontSize', O.fsPanel, 'Color', 'k', 'Interpreter', 'none');
        end
        if ~isempty(P(k).xlab)
            xlabel(ax, P(k).xlab, 'FontSize', O.fsPanel, 'Color', 'k', 'Interpreter', 'none');
        end
    end
    tidy_axes(AX, P, rows, cols, O);
    draw_footer(fig, B, footer, O);
    % Reserve the space a multi-line panel title needs above the top row.
    tl.Subtitle.String   = repmat({' '}, nt, 1);
    tl.Subtitle.FontSize = O.fsPanel;

    if ~isfolder(O.outdir);  mkdir(O.outdir);  end
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [O.width H], ...
             'PaperPosition', [0 0 O.width H], 'PaperPositionMode', 'manual', ...
             'InvertHardcopy', 'off');
    print(fig, fullfile(O.outdir, [file '.png']), '-dpng', '-r300');
    if ~isempty(O.pdfdir)
        if ~isfolder(O.pdfdir);  mkdir(O.pdfdir);  end
        print(fig, fullfile(O.pdfdir, [file '.pdf']), '-dpdf', '-vector');
    end
    close(fig);
    fprintf('  %s\n', file);
end


% ---- Axes ---------------------------------------------------------------------------

function style_axes(ax, O)
    set(ax, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'GridColor', [.55 .55 .55], ...
            'FontSize', O.fsPanel, 'FontName', O.font, 'Box', 'off', 'Layer', 'top', ...
            'TickDir', 'out', 'LineWidth', 0.6);
    ax.Toolbar.Visible = 'off';
    grid(ax, 'on');
end

function tidy_axes(AX, P, rows, cols, O)
% Drop repeated x-labels when all panels share the same x-axis, and give each row one
% y-scale when O.shareRows is set (panels of a row carry the same 'row' tag).
    n = numel(P);
    xl = get(AX(1), 'XLim');
    same = ~isempty(P(1).xlab);
    for k = 2:n
        same = same && strcmp(P(k).xlab, P(1).xlab) && isequal(get(AX(k), 'XLim'), xl);
    end
    if same
        for k = 1:n - cols
            xlabel(AX(k), '');
            set(AX(k), 'XTickLabel', []);
        end
    end
    if ~O.shareRows;  return;  end
    for r = 1:rows
        idx = (r-1)*cols + (1:cols);
        idx = idx(idx <= n);
        if numel(idx) < 2 || ~all(strcmp({P(idx).row}, P(idx(1)).row));  continue;  end
        full = idx(arrayfun(@(a) ~isempty(allchild(a)), AX(idx)));
        if isempty(full);  continue;  end
        lims = cell2mat(arrayfun(@(a) get(a, 'YLim'), AX(full), 'UniformOutput', false)');
        set(AX(idx), 'YLim', [min(lims(:,1)), max(lims(:,2))], 'YTickMode', 'auto');
        for j = 2:numel(idx)
            ylabel(AX(idx(j)), '');
            set(AX(idx(j)), 'YTickLabel', []);
        end
    end
end


% ---- Legend footer ------------------------------------------------------------------

function h = footer_height(B, O)
    if isempty(B);  h = 0;  return;  end
    [~, ~, hB] = block_layout(B, O);
    h = 0.30 + hB + 0.25;
end

function [xs, ys, hTot] = block_layout(B, O)
% Place legend blocks left to right, wrapping to a new row when the width runs out.
    n = numel(B);  xs = zeros(1, n);  ys = zeros(1, n);
    ws = zeros(1, n);  hs = zeros(1, n);
    for j = 1:n;  [ws(j), hs(j)] = block_size(B{j}, O);  end
    gap = 1.4;
    if n > 1;  gap = max(0.5, min(gap, (O.width - 1.2 - sum(ws)) / (n - 1)));  end
    x = 0.60;  row = 1;  rowTop = zeros(1, n);
    for j = 1:n
        if j > 1 && x + ws(j) > O.width - 0.40;  row = row + 1;  x = 0.60;  end
        xs(j) = x;  ys(j) = row;  rowTop(row) = max(rowTop(row), hs(j));
        x = x + ws(j) + gap;
    end
    rowH = rowTop(1:row);
    hTot = sum(rowH) + 0.25 * (row - 1);
    drop = cumsum([0, rowH(1:end-1) + 0.25]);
    ys = drop(ys);
end

function [w, h] = block_size(blk, O)
    hRow  = row_height(O.fsLegend);
    maxch = max(cellfun(@numel, {blk.entries.name}));
    w = 0.95 + 0.20 + char_width(O.fsLegend) * maxch + 0.30;
    h = numel(blk.entries) * hRow + 0.20;
    if ~isempty(blk.title)
        h = h + hRow;
        w = max(w, char_width(O.fsLegend) * numel(blk.title) + 0.6);
    end
end

function draw_footer(fig, B, footer, O)
    if footer <= 0;  return;  end
    ax = axes(fig, 'Units', 'centimeters', 'Position', [0 0 O.width footer]);
    set(ax, 'XLim', [0 O.width], 'YLim', [0 footer], 'Visible', 'off', 'Color', 'none');
    hold(ax, 'on');
    [xs, drop] = block_layout(B, O);
    for j = 1:numel(B)
        draw_block(ax, xs(j), footer - 0.25 - drop(j), B{j}, O);
    end
end

function draw_block(ax, x0, yTop, blk, O)
    fs = O.fsLegend;  hRow = row_height(fs);  y = yTop;
    if ~isempty(blk.title)
        text(ax, x0, y - 0.10, blk.title, 'FontSize', fs, 'FontName', O.font, ...
             'Color', 'k', 'FontWeight', 'bold', 'VerticalAlignment', 'cap', ...
             'Interpreter', 'none');
        y = y - hRow;
    end
    wSample = 0.95;
    for j = 1:numel(blk.entries)
        e  = blk.entries(j);
        yc = y - (j - 0.5) * hRow;
        plot(ax, [x0 x0 + wSample], [yc yc], 'Color', e.col, 'LineStyle', e.ls, ...
             'LineWidth', e.lw);
        if ~strcmp(e.mk, 'none')
            plot(ax, x0 + wSample/2, yc, 'Marker', e.mk, 'Color', e.col, ...
                 'MarkerFaceColor', e.col, 'MarkerSize', 3.2, 'LineStyle', 'none');
        end
        text(ax, x0 + wSample + 0.20, yc, e.name, 'FontSize', fs, 'FontName', O.font, ...
             'Color', 'k', 'VerticalAlignment', 'middle', 'Interpreter', 'none');
    end
end


% ---- Text metrics -------------------------------------------------------------------

function c = char_width(fs);  c = 0.0185 * fs;  end
function h = row_height(fs);  h = 0.046 * fs;   end

function lines = wrap(txt, wcm, fs, maxlines)
    if isempty(txt);  lines = {};  return;  end
    nch   = max(8, floor(wcm / char_width(fs)));
    lines = textwrap({txt}, nch);
    while numel(lines) > maxlines && nch < numel(txt)
        nch   = ceil(nch * 1.25);
        lines = textwrap({txt}, nch);
    end
    lines = lines(1:min(end, maxlines));
end

function f = document_font()
% The serif of the thesis (Palatino) when available.
    persistent chosen
    if ~isempty(chosen);  f = chosen;  return;  end
    available = listfonts;
    for cand = {'Palatino Linotype', 'Palatino', 'Book Antiqua', 'Times New Roman'}
        if any(strcmp(available, cand{1}));  chosen = cand{1};  f = chosen;  return;  end
    end
    chosen = get(groot, 'FactoryAxesFontName');  f = chosen;
end
