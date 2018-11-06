### Solver options ###
opts = TrajectoryOptimization.SolverOptions()
opts.square_root = false
opts.verbose = true
opts.z_min = 1e-8
opts.z_max = 10.0
opts.cost_intermediate_tolerance = 1e-3
opts.constraint_tolerance = 1e-3
opts.cost_tolerance = 1e-3
opts.iterations_outerloop = 50
opts.iterations = 250
opts.iterations_linesearch = 11
opts.τ = 0.25
opts.γ = 10.0
opts.ρ_initial = 0.0
opts.outer_loop_update = :default
opts.use_static = false
opts.resolve_feasible = false
opts.λ_second_order_update = false
opts.regularization_type = :control
opts.max_dt = 0.15
opts.min_dt = 0.05
opts.μ_initial_minimum_time_inequality = 1.0
opts.μ_initial_minimum_time_equality = 1.0
opts.ρ_forwardpass = 100.0
opts.gradient_tolerance=1e-4
opts.gradient_intermediate_tolerance=1e-4
opts.μ_max = 1e64
opts.λ_max = 1e64
opts.λ_min = -1e64
opts.ρ_max = 1e64
opts.R_minimum_time = 1e-3
opts.R_infeasible = 1e-3
opts.resolve_feasible = false
opts.live_plotting = true
opts.minimum_time_tf_estimate = 5.0
######################

### Set up model, objective, solver ###
model_cartpole, obj_uncon_cartpole = TrajectoryOptimization.Dynamics.cartpole_udp

## Constraints
# cartpole
u_min_cartpole = -30
u_max_cartpole = 30
x_min_cartpole = [-10; -1000; -1000; -1000]
x_max_cartpole = [10; 1000; 1000; 1000]

# -Constrained objective
obj_con_cartpole = ConstrainedObjective(obj_uncon_cartpole, u_min=u_min_cartpole, u_max=u_max_cartpole)

# System selection
model = model_cartpole
n = model.n
m = model.m
obj = obj_con_cartpole
u_max = u_max_cartpole
u_min = u_min_cartpole

dt = 0.1
solver = Solver(model,obj,integration=:rk3_foh,dt=dt,opts=opts)

N_mintime = solver.N
obj_mintime = ConstrainedObjective(0.0*obj.Q,(0.0)obj.R,0.0*obj.Qf,0.0,obj.x0,obj.xf,u_min=obj.u_min,u_max=obj.u_max)
solver_mintime = Solver(model,obj_mintime,integration=:rk3_foh,N=N_mintime,opts=opts)
opts.max_dt
opts.min_dt
U = zeros(m,solver.N)
U_mintime = rand(m,N_mintime)
X_interp = line_trajectory(solver_mintime)

# results,stats = solve(solver,U_mintime)
results_mintime,stats_mintime = solve(solver_mintime,U_mintime)#to_array(results_mintime.U)[1:m,:])#U_mintime)
# results_mintime,stats_mintime = solve(solver_mintime,to_array(results_mintime.U)[1:m,:],prevResults=results_mintime)#to_array(results_mintime.U)[1:m,:])#U_mintime)

# # println("Final state (    reg)-> res: $(results.X[end]), goal: $(solver.obj.xf)\n Iterations: $(stats["iterations"])\n Outer loop iterations: $(stats["major iterations"])\n Max violation: $(stats["c_max"][end])\n Max μ: $(maximum([to_array(results.μ)[:]; results.μN[:]]))\n Max abs(λ): $(maximum(abs.([to_array(results.λ)[:]; results.λN[:]])))\n")
println("Final state (mintime)->: $(results_mintime.X[end]), goal: $(solver_mintime.obj.xf)\n Iterations: $(stats_mintime["iterations"])\n Outer loop iterations: $(stats_mintime["major iterations"])\n Max violation: $(stats_mintime["c_max"][end])\n Max μ: $(maximum([to_array(results_mintime.μ)[:]; results_mintime.μN[:]]))\n Max abs(λ): $(maximum(abs.([to_array(results_mintime.λ)[:]; results_mintime.λN[:]])))\n")
#
p1 = plot(to_array(results_mintime.X)',ylabel="state",label="")
p2 = plot(to_array(results_mintime.U)[:,1:solver_mintime.N-1]',ylabel="control",xlabel="time step (k)",label="")
plot(p1,p2,layout=(2,1))
# #
# results_mintime.U[end]

# p1_ = plot(to_array(results.X)',ylabel="state",label="")
# p2_ = plot(to_array(results.U)[:,1:solver.N-1]',ylabel="control",xlabel="time step (k)",label="")
# plot(p1_,p2_,layout=(2,1))
# solver.obj.tf
