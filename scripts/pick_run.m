function r = pick_run(RES, scenario, damage, world)
%PICK_RUN  The solved run with the given scenario, damage flag and world, or [] if none.
    k = find([RES.scenario] == scenario & [RES.damage] == damage & [RES.world] == world ...
             & [RES.usable], 1);
    if isempty(k);  r = [];  else;  r = RES(k);  end
end
