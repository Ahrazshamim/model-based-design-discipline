function n = check_chart_layout(model, charts)
%CHECK_CHART_LAYOUT  Report anything that overlaps or is misparented in a model's charts.
%
%   n = CHECK_CHART_LAYOUT(model)          checks every Stateflow chart in the model
%   n = CHECK_CHART_LAYOUT(model, charts)  checks only the named charts
%                                          (char, string array or cellstr; names or paths)
%
%   Reports, per parallel region:
%     CLASH        two sibling state boxes, junctions or transition-label rectangles
%                  that intersect
%     OUTSIDE      a child whose rectangle is not fully inside its parent state
%     CHART-OWNED  a transition between two children of a region that is owned by the
%                  CHART instead of the region -- firing it exits and re-enters the
%                  whole chart, resetting every parallel region
%
%   Returns the number of findings. It must be 0 after every edit.
%
%   Example:
%       if check_chart_layout('myModel') > 0
%           error('layout regressed');
%       end
%
%   Part of the model-based-design-discipline skill (Rule 4). MIT licensed.

if nargin < 1 || isempty(model)
    error('check_chart_layout:noModel', 'Give a model name.');
end
if ~bdIsLoaded(model)
    load_system(model);
end

rt = sfroot;
allCharts = rt.find('-isa', 'Stateflow.Chart');
allCharts = allCharts(startsWith({allCharts.Path}, [model '/']) | strcmp({allCharts.Path}, model));

if nargin >= 2 && ~isempty(charts)
    if ischar(charts) || isstring(charts)
        charts = cellstr(charts);
    end
    keep = false(size(allCharts));
    for k = 1:numel(allCharts)
        keep(k) = any(strcmp(allCharts(k).Name, charts)) || any(strcmp(allCharts(k).Path, charts));
    end
    missing = setdiff(charts, [{allCharts(keep).Name}, {allCharts(keep).Path}]);
    for k = 1:numel(missing)
        fprintf('  WARNING: no chart named "%s" in %s\n', missing{k}, model);
    end
    allCharts = allCharts(keep);
end

if isempty(allCharts)
    fprintf('no Stateflow charts found in %s\n', model);
    n = 0;
    return
end

n = 0;
for c = 1:numel(allCharts)
    ch = allCharts(c);
    fprintf('=== %s\n', ch.Path);

    % ---- collect every drawn rectangle, tagged with its parent container -----
    boxes = {};     % {parentName, kind, name, rect}
    st = ch.find('-isa', 'Stateflow.State');
    for i = 1:numel(st)
        boxes(end+1, :) = {parentName(st(i)), 'state', st(i).Name, st(i).Position}; %#ok<AGROW>
    end
    jn = ch.find('-isa', 'Stateflow.Junction');
    for i = 1:numel(jn)
        ctr = jn(i).Position.Center;
        rad = jn(i).Position.Radius;
        boxes(end+1, :) = {parentName(jn(i)), 'junction', sprintf('J%d', i), ...
                           [ctr(1)-rad ctr(2)-rad 2*rad 2*rad]}; %#ok<AGROW>
    end
    tr = ch.find('-isa', 'Stateflow.Transition');
    for i = 1:numel(tr)
        lbl = strtrim(strrep(tr(i).LabelString, '?', ''));
        if isempty(lbl)
            continue    % a bare arc carries no text, so nothing to collide with
        end
        boxes(end+1, :) = {parentName(tr(i)), 'label', shortLabel(tr(i)), tr(i).LabelPosition}; %#ok<AGROW>
    end

    if isempty(boxes)
        continue
    end

    % ---- siblings must not overlap ------------------------------------------
    % A state legitimately contains its own children, so only siblings are compared.
    parents = unique(boxes(:, 1));
    for p = 1:numel(parents)
        ix = find(strcmp(boxes(:, 1), parents{p}));
        for a = 1:numel(ix)
            for b = a+1:numel(ix)
                A = boxes{ix(a), 4};
                B = boxes{ix(b), 4};
                bothStates = strcmp(boxes{ix(a), 2}, 'state') && strcmp(boxes{ix(b), 2}, 'state');
                if bothStates
                    ov = overlapArea(A, B);          % boxes may touch, not overlap
                else
                    ov = overlapArea(pad(A), pad(B)); % labels need breathing room
                end
                if ov > 0
                    n = n + 1;
                    fprintf('  CLASH in %-16s %s "%s" x %s "%s"  (%d px^2)\n', parents{p}, ...
                        boxes{ix(a), 2}, boxes{ix(a), 3}, ...
                        boxes{ix(b), 2}, boxes{ix(b), 3}, round(ov));
                end
            end
        end
    end

    % ---- a transition between two children of a region must belong to that
    %      region; a chart-owned arc resets every parallel region when it fires
    for t = ch.find('-isa', 'Stateflow.Transition')'
        if ~isa(t.getParent, 'Stateflow.Chart'); continue; end
        if isempty(t.Source) || isempty(t.Destination); continue; end
        if ~isa(t.Source, 'Stateflow.State') || ~isa(t.Destination, 'Stateflow.State'); continue; end
        if isa(t.Source.getParent, 'Stateflow.Chart'); continue; end
        n = n + 1;
        fprintf('  CHART-OWNED arc %s -> %s (should belong to %s)\n', ...
            t.Source.Name, t.Destination.Name, t.Source.getParent.Name);
    end

    % ---- children must sit inside their parent -------------------------------
    for i = 1:size(boxes, 1)
        pn = boxes{i, 1};
        if strcmp(pn, '(chart)'); continue; end
        P = [];
        for k = 1:numel(st)
            if strcmp(st(k).Name, pn); P = st(k).Position; end
        end
        if isempty(P); continue; end
        R = boxes{i, 4};
        if R(1) < P(1) || R(2) < P(2) || R(1)+R(3) > P(1)+P(3) || R(2)+R(4) > P(2)+P(4)
            n = n + 1;
            fprintf('  OUTSIDE %-16s %s "%s" rect=%s parent=%s\n', pn, ...
                boxes{i, 2}, boxes{i, 3}, mat2str(round(R)), mat2str(round(P)));
        end
    end
end

fprintf('total findings: %d\n', n);
end

% -----------------------------------------------------------------------------

function s = parentName(o)
p = o.getParent;
if isa(p, 'Stateflow.Chart')
    s = '(chart)';
else
    s = p.Name;
end
end

function s = shortLabel(t)
s = regexprep(t.LabelString, '\s+', ' ');
if numel(s) > 42
    s = [s(1:42) '..'];
end
end

function r = pad(r)
r = [r(1)-4 r(2)-4 r(3)+8 r(4)+8];
end

function a = overlapArea(A, B)
dx = min(A(1)+A(3), B(1)+B(3)) - max(A(1), B(1));
dy = min(A(2)+A(4), B(2)+B(4)) - max(A(2), B(2));
if dx > 0 && dy > 0
    a = dx * dy;
else
    a = 0;
end
end
