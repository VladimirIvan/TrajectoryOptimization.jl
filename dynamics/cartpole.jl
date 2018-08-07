## Cartpole / Inverted Pendulum
#TODO test
urdf_folder = joinpath(Pkg.dir("TrajectoryOptimization"), "dynamics/urdf")
urdf_cartpole = joinpath(urdf_folder, "cartpole.urdf")

model = Model(urdf_cartpole,[1.;0.]) # underactuated, only control of slider

# initial and goal states
x0 = [0.;pi;0.;0.]
xf = [0.;0.;0.;0.]

# costs
Q = 0.001*eye(model.n)
Qf = 150.0*eye(model.n)
R = 0.0001*eye(model.m)

# simulation
tf = 5.0
dt = 0.1

obj_uncon = UnconstrainedObjective(Q, R, Qf, tf, x0, xf)

cartpole = [model, obj_uncon]
