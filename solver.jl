include("solver_options.jl")

"""
    check_inplace_dynamics(model)
Determine if the dynamics in model are in place. i.e. the function call is of
the form `f!(xdot,x,u)`, where `xdot` is modified in place. Returns a boolean.
"""
function is_inplace_dynamics(model::Model)::Bool
    x = rand(model.n)
    u = rand(model.m)
    xdot = rand(model.n)
    try
        model.f(xdot,x,u)
    catch x
        if x isa MethodError
            return false
        end
    end
    return true
end

"""
    wrap_inplace(f)
Makes the dynamics function `f(x,u)` appear to operate as an inplace operation of the
form `f!(xdot,x,u)`.
"""
function wrap_inplace(f::Function)
    f!(xdot,x,u) = copy!(xdot, f(x,u))
end

struct Solver
    model::Model
    obj::Objective
    opts::SolverOptions
    dt::Float64
    fd::Function  # discrete dynamics
    F::Function
    N::Int

    function Solver(model::Model, obj::Objective; integration::Symbol=:rk4, dt=0.01, opts::SolverOptions=SolverOptions())
        N = Int(floor(obj.tf/dt));

        # Make dynamics inplace
        if is_inplace_dynamics(model)
            f! = model.f
        else
            f! = wrap_inplace(model.f)
        end
        opts.inplace_dynamics = true

        # Get integration scheme
        if isdefined(iLQR,integration)
            discretizer = eval(integration)
        else
            # throw(ArgumentError("$integration is not a defined integration scheme"))
        end

        # Generate discrete dynamics equations
        fd! = discretizer(f!, dt)
        f_aug! = f_augmented!(f!, model.n, model.m)
        fd_aug! = discretizer(f_aug!)
        F!(J,Sdot,S) = ForwardDiff.jacobian!(J,fd_aug!,Sdot,S)

        # Auto-diff discrete dynamics
        function Jacobians!(x,u)
            nm1 = model.n + model.m + 1
            J = zeros(nm1, nm1)
            S = zeros(nm1)
            S[1:model.n] = x
            S[model.n+1:end-1] = u
            S[end] = dt
            Sdot = zeros(S)
            F_aug = F!(J,Sdot,S)
            fx = F_aug[1:model.n,1:model.n]
            fu = F_aug[1:model.n,model.n+1:model.n+model.m]
            return fx, fu
        end
        new(model, obj, opts, dt, fd!, Jacobians!, N)

    end
end

abstract type SolverResults end

struct UnconstrainedResults <: SolverResults
    X::Array{Float64,2}
    U::Array{Float64,2}
    K::Array{Float64,3}
    d::Array{Float64,2}
    X_::Array{Float64,2}
    U_::Array{Float64,2}
    function UnconstrainedResults(X,U,K,d,X_,U_)
        new(X,U,K,d,X_,U_)
    end
end

function UnconstrainedResults(n::Int,m::Int,N::Int)
    X = zeros(n,N)
    U = zeros(m,N-1)
    K = zeros(m,n,N-1)
    d = zeros(m,N-1)
    X_ = zeros(n,N)
    U_ = zeros(m,N-1)
    UnconstrainedResults(X,U,K,d,X_,U_)
end

struct ConstrainedResults <: SolverResults
    X::Array{Float64,2}
    U::Array{Float64,2}
    K::Array{Float64,3}
    d::Array{Float64,2}
    X_::Array{Float64,2}
    U_::Array{Float64,2}
    C::Array{Float64,2}
    Iμ::Array{Float64,3}
    LAMBDA::Array{Float64,2}
    MU::Array{Float64,2}

    CN::Array{Float64,1}
    IμN::Array{Float64,2}
    λN::Array{Float64,1}
    μN::Array{Float64,1}

    function ConstrainedResults(X,U,K,d,X_,U_,C,Iμ,LAMBDA,MU)
        n = size(X,1)
        # Terminal Constraints (make 2D so it works well with stage values)
        CN = zeros(n)
        IμN = zeros(n,n)
        λN = zeros(n)
        μN = zeros(n)
        new(X,U,K,d,X_,U_,C,Iμ,LAMBDA,MU,CN,IμN,λN,μN)
    end
    function ConstrainedResults(X,U,K,d,X_,U_,C,Iμ,LAMBDA,MU,CN,IμN,λN,μN)
        new(X,U,K,d,X_,U_,C,Iμ,LAMBDA,MU,CN,IμN,λN,μN)
    end
end

function ConstrainedResults(n,m,p,N,p_N=n)
    X = zeros(n,N)
    U = zeros(m,N-1)
    K = zeros(m,n,N-1)
    d = zeros(m,N-1)
    X_ = zeros(n,N)
    U_ = zeros(m,N-1)

    # Stage Constraints
    C = zeros(p,N-1)
    Iμ = zeros(p,p,N-1)
    LAMBDA = zeros(p,N-1)
    MU = ones(p,N-1)

    # Terminal Constraints (make 2D so it works well with stage values)
    C_N = zeros(p_N)
    Iμ_N = zeros(p_N,p_N)
    λ_N = zeros(p_N)
    μ_N = ones(p_N)

    ConstrainedResults(X,U,K,d,X_,U_,
        C,Iμ,LAMBDA,MU,
        C_N,Iμ_N,λ_N,μ_N)

end

# struct SolverResultsConstrained <: SolverResults
#     C::Array{Float64}
# end
