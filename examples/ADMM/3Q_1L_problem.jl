include("methods.jl")
include("models.jl")

function build_lift_problem(x0, xf, Q, r_lift, _cyl, num_lift)
    # Discretization
    N = 51
    dt = 0.1

    ### Model
    n_lift = quadrotor_lift.n
    m_lift = quadrotor_lift.m

    ### Constraints
    u_lim_l = -Inf*ones(m_lift)
    u_lim_u = Inf*ones(m_lift)
    u_lim_l[1:4] .= 0.
    u_lim_u[1:4] .= 9.81*(quad_params.m + 1.)/4.0
    bnd = BoundConstraint(n_lift,m_lift,u_min=u_lim_l,u_max=u_lim_u)

    function cI_cylinder_lift(c,x,u)
        for i = 1:length(_cyl)
            c[i] = circle_constraint(x[1:3],_cyl[i][1],_cyl[i][2],_cyl[i][3] + 2*r_lift)
        end
    end
    obs_lift = Constraint{Inequality}(cI_cylinder_lift,n_lift,m_lift,length(_cyl),:obs_lift)

    con = Constraints(N)
    for k = 1:N-1
        con[k] += obs_lift + bnd
    end
    con[N] += goal_constraint(xf)

    ### Objective
    Qf = Diagonal(1000.0I,n_lift)
    r_diag = ones(m_lift)
    r_diag[1:4] .= 10.0e-3
    r_diag[5:7] .= 1.0e-6
    R_lift = Diagonal(r_diag)

    obj_lift = LQRObjective(Q, R_lift, Qf, xf, N)

    u_lift = zeros(m_lift)
    u_lift[1:4] .= 9.81*(quad_params.m + 1.)/12.
    u_lift[5:7] = u_load
    U0_lift = [u_lift for k = 1:N-1]

    prob_lift = Problem(quadrotor_lift,
                obj_lift,
                U0_lift,
                integration=:midpoint,
                constraints=con,
                x0=x0,
                xf=xf,
                N=N,
                dt=dt)
end

function build_load_problem(x0, xf, r_load, _cyl, num_lift)
    # Discretization
    N = 51
    dt = 0.1

    n_load = doubleintegrator3D_load.n
    m_load = doubleintegrator3D_load.m

    # Constraints
    function cI_cylinder_load(c,x,u)
        for i = 1:length(_cyl)
            c[i] = circle_constraint(x[1:3],_cyl[i][1],_cyl[i][2],_cyl[i][3] + 2*r_load)
        end
    end
    obs_load = Constraint{Inequality}(cI_cylinder_load,n_load,m_load,length(_cyl),:obs_load)

    constraints_load = Constraints(N)
    for k = 1:N-1
        constraints_load[k] += obs_load
    end
    constraints_load[N] += goal_constraint(xf)

    # Objective
    Q_load = 0.0*Diagonal(I,n_load)
    Qf_load = 0.0*Diagonal(I,n_load)
    R_load = 1.0e-6*Diagonal(I,m_load)
    obj_load = LQRObjective(Q_load,R_load,Qf_load,xf,N)

    # Initial controls
    u_load = [0.;0.;-9.81/num_lift]
    U0_load = [-1.0*[u_load;u_load;u_load] for k = 1:N-1]

    prob_load = Problem(doubleintegrator3D_load,
                obj_load,
                U0_load,
                integration=:midpoint,
                constraints=constraints_load,
                x0=x0,
                xf=xf,
                N=N,
                dt=dt)
end