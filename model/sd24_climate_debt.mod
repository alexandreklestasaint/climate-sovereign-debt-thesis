// =====================================================================================
//  sd24_climate_debt.mod
//
//  Green transition, climate damage and sovereign debt in a closed economy (France).
//  Reimplementation of Seghini and Dees, "The Green Transition and Public Finances"
//  (Banque de France WP 949, 2024; Macroeconomic Dynamics, 2025), extended with five
//  climate damage specifications, including the two-kernel dynamic damage function of
//  Bilal and Kanzig.
//
//  A national carbon budget forces the economy to abate a rising share of its emissions
//  until net zero. Part of the abatement bill can sit on the public budget, so the
//  transition moves public debt; debt moves the probability of sovereign default, which
//  moves the interest rate paid by the government. Climate damage lowers productivity.
//
//  The brown (emitting) economy is the initial condition, the green (net-zero) economy is
//  the terminal steady state, and the path in between is solved under perfect foresight.
//
//  Usage
//      dynare sd24_climate_debt.mod -Dscenario=1 -Ddamage=0 -Dworld=1
//
//  Flags
//      scenario  1 carbon tax
//                2 carbon tax, a quarter of the revenue recycled into public consumption
//                3 carbon tax and a 90 % subsidy on private abatement
//                4 public abatement (99 % of the effort), asymmetric costs
//                5 public abatement (99 % of the effort), symmetric costs
//      damage    0 none
//                1 DICE-2023, Barrage and Nordhaus (2024)
//                2 Kalkuhl and Wenz (2020)
//                3 Seghini and Dees (2025), exponential after Dietz and Venmans (2019)
//                4 Seghini, Dees and De Gaye (2026), same form, four times the severity
//                5 Bilal and Kanzig (2026), two-kernel dynamic damage
//      world     1 carbon budget of 240 GtCO2 (about 1.5 degrees)
//                2 carbon budget of 3055 GtCO2 (about 3 degrees)
//      inertia   inertia of the fiscal rule (default 0.904)
//      horizon   simulated quarters (default 800 in world 1, 1600 in world 2)
//
//  Calibration: France, quarterly, as in the working-paper version of Seghini and Dees,
//  with the fiscal-rule inertia held at 0.904 in every simulation, the highest value at
//  which all 60 configurations of run_all.m have a solution.
// =====================================================================================

@#ifndef scenario
    @#define scenario = 1
@#endif
@#ifndef damage
    @#define damage = 0
@#endif
@#ifndef world
    @#define world = 1
@#endif
@#ifndef inertia
    @#define inertia = 0.904
@#endif
@#ifndef horizon
    @#if world == 1
        @#define horizon = 800
    @#else
        @#define horizon = 1600
    @#endif
@#endif
// Decay of the initial guess handed to the solver: the guessed path leaves the brown
// economy geometrically at this rate. Slower for the longer transition of world 2.
@#if world == 1
    @#define guess_decay = 0.99
@#else
    @#define guess_decay = 0.995
@#endif


// =====================================================================================
//  Endogenous variables (detrended by the productivity trend; carbon stocks in GtCO2)
// =====================================================================================
var
    c           ${c}$            (long_name='Consumption')
    y           ${y}$            (long_name='Output')
    i_inv       ${i}$            (long_name='Investment')
    k           ${k}$            (long_name='Capital stock')
    l           ${l}$            (long_name='Hours worked')
    w           ${w}$            (long_name='Real wage')
    rk          ${r^k}$          (long_name='Rental rate of capital')
    lambda_z    ${\lambda}$      (long_name='Marginal utility of consumption')
    lambda_k    ${\lambda^k}$    (long_name='Shadow value of installed capital')
    qk          ${q}$            (long_name='Tobin Q')
    R           ${R}$            (long_name='Risk-free gross interest rate')
    Theta       ${\Theta}$       (long_name='Share of unit revenue left to pay factors')

    m           ${m}$            (long_name='Private abatement rate')
    mg          ${m^g}$          (long_name='Public abatement rate')
    m_total     ${m^{tot}}$      (long_name='Total abatement rate required by the carbon budget')
    e           ${e}$            (long_name='Emissions')
    pe          ${p^e}$          (long_name='Carbon price')
    hn          ${h}$            (long_name='Share of the national carbon budget already spent')
    hG          ${H^G}$          (long_name='World cumulative emissions, GtCO2')
    That        ${\hat T}$       (long_name='Warming above pre-industrial levels, degrees')
    Df          ${D_f}$          (long_name='Productivity net of climate damage')
    XB          ${X^B}$          (long_name='Slow memory of past warming (two-kernel damage)')
    XC          ${X^C}$          (long_name='Fast memory of past warming (two-kernel damage)')

    b           ${b}$            (long_name='Public debt to GDP')
    rd          ${R^d}$          (long_name='Gross interest rate on government bonds')
    pd          ${PD}$           (long_name='Quarterly probability of sovereign default')
    tau         ${\tau}$         (long_name='Lump-sum tax to GDP')
    surplus     ${s}$            (long_name='Primary surplus to GDP')
    phi_tau     ${\phi_\tau}$    (long_name='Inertia of the fiscal rule')
;

// Policy instruments. Declared exogenous so that they are zero in the brown economy and
// at their scenario value from the first simulated period on.
varexo
    theta_policy ${\theta}$   (long_name='Public share of total abatement')
    sA           ${s_A}$      (long_name='Subsidy rate on private abatement')
    omega_g      ${\omega_g}$ (long_name='Share of carbon revenue recycled into public consumption')
;


// =====================================================================================
//  Parameters
// =====================================================================================
parameters
    beta beta_bar kappa delta sigma_l mu_L iota z exp_z
    theta1 theta2 theta3 theta4 theta4_ratio
    xi0 p_curve E0n E0G HG_init H_init hn_init lambda_TCRE T_pre
    Dbar s_DICE s_KW s_SD s_SDDG s_BK psi2 kw1 kw2 gamma3 gamma4 gamma_T A_BK kB kC
    sigma_B b_M b_star haircut f_cost g
    phi_b phi_bar phi_tau_y tau_star tau_brown m_total_brown dmg_gap
    theta_target sA_target omega_g_target
    is_brown
;

// ---- Preferences and technology ------------------------------------------------------
beta     = 0.995;    // 0.99 in the paper's text; 0.995 matches the 4.5 % bond rate of its figures
kappa    = 0.33;
delta    = 0.025;
sigma_l  = 1;
mu_L     = 19.841;   // hours worked about a third of the time endowment
iota     = 15;
z        = 0.005;    // quarterly trend growth

// ---- Abatement costs: theta1 m^theta2 (private), theta3 mg^theta4 (public) ------------
theta1   = 0.023;
theta2   = 1.8;
theta3   = 0.023;

// ---- Carbon cycle and carbon budget --------------------------------------------------
// Carbon clock of Seghini, Dees and De Gaye (2026): 0.00053 degrees per GtCO2 on a CO2
// stock of 2650 GtCO2 at the start date, when warming is 1.4 degrees.
xi0         = 0.17;      // carbon intensity of unabated output
HG_init     = 2650;
lambda_TCRE = 0.00053;
T_pre       = 1.4;
H_init      = 0.01;      // sets initial abatement near 7 %, as in the paper's figures
@#if world == 1
    E0G = 240;   E0n = 1.9;               p_curve = 0.5;
@#else
    E0G = 3055;  E0n = 1.9 * 3055 / 240;  p_curve = 3.0;
@#endif

// ---- Sovereign debt and the fiscal rule ----------------------------------------------
sigma_B   = 0.08;        // dispersion of the fiscal limit
b_M       = 1.35;        // fiscal limit
b_star    = 1.10;        // debt target
haircut   = 0.70;
f_cost    = 0.30;
g         = 0.0575;      // public consumption to GDP (working-paper table)
phi_b     = 0.2;
phi_bar   = @{inertia};  // inertia of the fiscal rule
phi_tau_y = 0.9;         // slows the rule when damage has cut output and debt is above target

// ---- Climate damage ------------------------------------------------------------------
psi2    = 0.003467;      // DICE-2023: 1 - psi2 T^2, a loss of output (enters with 1-kappa)
kw1     = 0.0335;        // Kalkuhl and Wenz: 1 - kw1 T - kw2 T^2, a loss of productivity
kw2     = 0.0009;
gamma3  = 0.02;          // Seghini and Dees: exp(-gamma3/2 (gamma4 hG)^2)
gamma4  = lambda_TCRE;
A_BK    = -7.0217;       // Bilal and Kanzig kernel A (e^{-Bs} - e^{-Cs}), per year;
kB      = 0.5784;        // parameters provided by D. Kanzig. Long-run slope
kC      = 0.5870;        // A (1/B - 1/C) = -0.178 per degree

s_DICE = 0;  s_KW = 0;  s_SD = 0;  s_SDDG = 0;  s_BK = 0;  gamma_T = 0;
@#if damage == 1
    s_DICE = 1;
@#endif
@#if damage == 2
    s_KW = 1;
@#endif
@#if damage == 3
    s_SD = 1;
@#endif
@#if damage == 4
    s_SDDG = 1;  gamma_T = 0.08;
@#endif
@#if damage == 5
    s_BK = 1;
@#endif

// Every specification is normalised so that the economy starts at the same output: the
// observed level identifies the product of underlying productivity and damage already
// incurred, not the two separately.
Dbar = 1 / ( (1 - s_DICE - s_KW - s_SD - s_SDDG - s_BK)
           + s_DICE * (1 - psi2*T_pre^2)^(1-kappa)
           + s_KW   * (1 - kw1*T_pre - kw2*T_pre^2)
           + s_SD   * exp(-gamma3/2 * (gamma4*HG_init)^2)
           + s_SDDG * exp(-gamma_T/2 * T_pre^2)
           + s_BK   * exp(A_BK * T_pre * (1/kB - 1/kC)) );

// ---- Policy scenario -----------------------------------------------------------------
@#if scenario == 1
    theta_target = 0.00;  sA_target = 0.0;  omega_g_target = 0.00;  theta4_ratio = 0.58;
@#endif
@#if scenario == 2
    theta_target = 0.00;  sA_target = 0.0;  omega_g_target = 0.25;  theta4_ratio = 0.58;
@#endif
@#if scenario == 3
    theta_target = 0.00;  sA_target = 0.9;  omega_g_target = 0.00;  theta4_ratio = 0.58;
@#endif
@#if scenario == 4
    theta_target = 0.99;  sA_target = 0.0;  omega_g_target = 0.00;  theta4_ratio = 0.58;
@#endif
@#if scenario == 5
    theta_target = 0.99;  sA_target = 0.0;  omega_g_target = 0.00;  theta4_ratio = 1.00;
@#endif

// ---- Derived ---------------------------------------------------------------------------
exp_z    = exp(z);
beta_bar = beta / exp_z;
theta4   = theta4_ratio * theta2;
hn_init  = H_init / E0n;

// ---- Overwritten by the steady-state block ---------------------------------------------
tau_star      = 0.25;    // tax rate of the green economy
tau_brown     = 0.25;    // tax rate of the brown economy
m_total_brown = 0.01;    // abatement rate of the brown economy
dmg_gap       = 0;       // output lost to damage at the start date
is_brown      = 1;       // 1 while the brown economy is computed, 0 for the green one


// =====================================================================================
//  Model
// =====================================================================================
model;
    #emis_base  = 1 - m - mg;
    #carbon_rev = pe * xi0 * emis_base;           // carbon tax revenue, share of output
    // Domain guards for the fractional powers; inactive at both steady states.
    #m_pos      = max(m, 0);
    #mg_pos     = max(mg, 0);
    #H_pos      = max(hn(-1), 0);
    #abate_priv = theta1 * m_pos^theta2;
    #abate_pub  = theta3 * mg_pos^theta4;
    #recyc_g    = omega_g * carbon_rev;            // revenue recycled into public consumption

    // ---- Climate -----------------------------------------------------------------------
    [name='Slow memory of past warming']
    XB = exp(-kB*0.25)*XB(-1) + That(-1) * (1 - exp(-kB*0.25))/kB;

    [name='Fast memory of past warming']
    XC = exp(-kC*0.25)*XC(-1) + That(-1) * (1 - exp(-kC*0.25))/kC;

    [name='Climate damage on productivity']
    Df = Dbar * ( (1 - s_DICE - s_KW - s_SD - s_SDDG - s_BK)
                + s_DICE * (1 - psi2*That^2)^(1-kappa)
                + s_KW   * (1 - kw1*That - kw2*That^2)
                + s_SD   * exp(-gamma3/2 * (gamma4*hG)^2)
                + s_SDDG * exp(-gamma_T/2 * That^2)
                + s_BK   * exp(A_BK * (XB - XC)) );

    // ---- Production --------------------------------------------------------------------
    [name='Production function']
    y = Df * k(-1)^kappa * l^(1-kappa);

    [name='Labour demand']
    w = (1-kappa) * Theta * y / l;

    [name='Capital demand']
    rk = kappa * Theta * y / k(-1);

    [name='Zero profit']
    Theta + (1-sA)*abate_priv + carbon_rev = 1;

    // ---- Emissions and the carbon budget -----------------------------------------------
    [name='Emissions']
    e = xi0 * emis_base * y;

    [name='Share of the national carbon budget spent']
    hn = hn(-1) + e/E0n;

    [name='World cumulative emissions']
    hG = HG_init + E0G * (hn - hn_init);

    [name='Warming']
    That = T_pre + lambda_TCRE * (hG - HG_init);

    [name='Mitigation rule']
    m_total = H_pos^p_curve;

    [name='Abatement adds up']
    m + mg = m_total;

    [name='Public abatement']
    mg = theta_policy * m_total;

    [name='Carbon price']
    pe = (1-sA) * theta1 * theta2 * m_pos^(theta2-1) / xi0;

    // ---- Households --------------------------------------------------------------------
    [name='Marginal utility of consumption']
    lambda_z = 1 / c;

    [name='Labour supply']
    mu_L * l^sigma_l = lambda_z * w;

    [name='Investment with adjustment costs']
    lambda_z = lambda_k * (1 - iota/2*(i_inv*exp_z/i_inv(-1) - exp_z)^2
               - iota*(i_inv*exp_z/i_inv(-1) - exp_z)*(i_inv*exp_z/i_inv(-1)))
               + beta_bar * lambda_k(+1) * iota * (i_inv(+1)*exp_z/i_inv - exp_z)
               * (i_inv(+1)*exp_z/i_inv)^2;

    [name='Value of installed capital']
    lambda_k = beta_bar * lambda_z(+1) * rk(+1) + beta_bar * (1-delta) * lambda_k(+1);

    [name='Tobin Q']
    qk = lambda_k / lambda_z;

    [name='Capital accumulation']
    k = (1-delta)/exp_z * k(-1) + i_inv/exp_z * (1 - iota/2*(i_inv*exp_z/i_inv(-1) - exp_z)^2);

    [name='Risk-free rate']
    R = lambda_z / (beta_bar * lambda_z(+1));

    // ---- Sovereign debt ----------------------------------------------------------------
    [name='Default probability']
    pd = normcdf((log(b) - log(b_M)) / sigma_B);

    [name='Bond rate']
    rd = R / (1 - f_cost * haircut * pd(+1));

    [name='Primary surplus']
    surplus = tau + carbon_rev - recyc_g - g - sA*abate_priv - abate_pub;

    [name='Debt dynamics']
    b = b(-1) * rd(-1) * y(-1) / (y * exp_z) - surplus;

    [name='Inertia of the fiscal rule']
    phi_tau = phi_bar + phi_tau_y * dmg_gap * (b(-1) - b_star);

    // The tax target moves from the brown to the green tax rate in step with abatement.
    #tau_target = tau_brown + (tau_star - tau_brown) * (m_total - m_total_brown)/(1 - m_total_brown);

    [name='Fiscal rule']
    tau = phi_tau * (tau(-1) + phi_b*(b - b(-1)))
        + (1 - phi_tau) * (tau_target + phi_b*(b - b_star));

    // ---- Market clearing ---------------------------------------------------------------
    [name='Resource constraint']
    y = c + i_inv + (g + recyc_g)*y + abate_priv*y + abate_pub*y;
end;


// =====================================================================================
//  Steady state. One block computes either economy: brown (is_brown = 1, carbon stock at
//  its start value) or green (is_brown = 0, budget exhausted, abatement total).
// =====================================================================================
steady_state_model;
    hn      = is_brown * hn_init + (1 - is_brown) * 1;
    m_total = hn^p_curve;
    mg      = theta_policy * m_total;
    m       = m_total - mg;
    emitting_share = 1 - m_total;

    pe            = (1 - sA) * theta1 * theta2 * m^(theta2-1) / xi0;
    cost_private  = theta1 * m^theta2;
    cost_public   = theta3 * mg^theta4;
    carbon_income = pe * xi0 * emitting_share;
    recyc_g_ss    = omega_g * carbon_income;
    Theta         = 1 - (1 - sA)*cost_private - carbon_income;

    hG   = HG_init + E0G * (hn - hn_init);
    That = T_pre + lambda_TCRE * (hG - HG_init);
    // The kernel memories start full: the economy has already absorbed past warming.
    XB   = That / kB;
    XC   = That / kC;
    Df   = Dbar * ( (1 - s_DICE - s_KW - s_SD - s_SDDG - s_BK)
                  + s_DICE * (1 - psi2*That^2)^(1-kappa)
                  + s_KW   * (1 - kw1*That - kw2*That^2)
                  + s_SD   * exp(-gamma3/2 * (gamma4*hG)^2)
                  + s_SDDG * exp(-gamma_T/2 * That^2)
                  + s_BK   * exp(A_BK * (XB - XC)) );

    // Debt sits at its target in both steady states.
    R  = exp_z / beta;
    b  = b_star;
    pd = normcdf((log(b) - log(b_M)) / sigma_B);
    rd = R / (1 - f_cost * haircut * pd);
    rk = R - (1-delta);

    k_over_y  = Theta * kappa / rk;
    i_over_y  = (exp_z - 1 + delta) * k_over_y;
    left_over = 1 - i_over_y - g - recyc_g_ss - cost_private - cost_public;   // c / y

    scale_y   = (Df * k_over_y^kappa)^(1/(1-kappa));
    work_term = scale_y^(1+sigma_l) * Theta*(1-kappa) / mu_L;
    y     = sqrt(4*left_over*work_term) / (2*left_over);
    l     = y / scale_y;
    c     = left_over * y;
    k     = k_over_y * y;
    i_inv = i_over_y * y;
    w     = Theta * (1-kappa) * y / l;
    e     = xi0 * emitting_share * y;

    surplus = b * (rd/exp_z - 1);
    tau     = surplus - carbon_income + recyc_g_ss + g + sA*cost_private + cost_public;

    lambda_z = 1 / c;
    lambda_k = beta_bar * lambda_z * rk / (1 - beta_bar*(1-delta));
    qk       = lambda_k / lambda_z;

    // Parameters written here: the two ends of the tax target, and the start-date output
    // gap due to damage (zero without damage).
    tau_star      = (1 - is_brown) * tau      + is_brown * tau_star;
    tau_brown     = is_brown * tau            + (1 - is_brown) * tau_brown;
    m_total_brown = is_brown * m_total        + (1 - is_brown) * m_total_brown;
    phi_tau       = phi_bar;
    dmg_gap       = is_brown * ( y * ((Dbar/Df)^(1/(1-kappa)) - 1) ) + (1 - is_brown) * dmg_gap;
end;


// =====================================================================================
//  Transition
// =====================================================================================

// 1. The brown economy. It still emits, so it is not a rest point of the carbon
//    accumulation equation; the block is used only to evaluate it (hence nocheck).
initval;
    hn           = hn_init;
    theta_policy = 0;
    sA           = 0;
    omega_g      = 0;
end;
steady(nocheck);
brown_ss_ = oo_.steady_state;
options_.steadystate.nocheck = false;

// 2. The green economy, the only true steady state: budget exhausted, zero emissions.
//    The policy values set here hold in every simulated period.
set_param_value('is_brown', 0);
initval;
    hn           = 1;
    theta_policy = theta_target;
    sA           = sA_target;
    omega_g      = omega_g_target;
end;
steady;
check;

perfect_foresight_setup(periods = @{horizon});

// 3. The brown economy enters as history (the lagged values of the first period), and
//    the initial guess leaves it geometrically towards the green economy.
M_.endo_histval = brown_ss_;
oo_.endo_simul(:,1) = brown_ss_;
ini_traj_ = oo_.endo_simul(:,1);
ter_traj_ = oo_.endo_simul(:,end);
npath_    = size(oo_.endo_simul,2) - 2;
oo_.endo_simul(:,2:end-1) = ter_traj_ + (ini_traj_ - ter_traj_) .* (@{guess_decay} .^ (1:npath_));

perfect_foresight_solver(maxit = 100);
