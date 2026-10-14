function z = series_of(r, name, cols)
%SERIES_OF  Path of one endogenous variable of a run, over the given columns of r.sim.
%   Column 1 is the brown economy (initial condition), column 2 the first simulated quarter.
    z = r.sim(strcmp(r.endo_names, name), cols);
end
