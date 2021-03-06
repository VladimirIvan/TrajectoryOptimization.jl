# # include("quaternions.jl")
# # using Quaternions
# export
#       trim_controls
#
# struct Quadrotor{Q,T} <: AbstractModel #RigidBody{Quat{VectorPart}}
#       n::Int
#       m::Int
#       mass::T
#       J::SMatrix{3,3,T,9}
#       Jinv::SMatrix{3,3,T,9}
#       gravity::SVector{3,T}
#       motor_dist::T
#       kf::T
#       km::T
#       info::Dict{Symbol,Any}
# end
#
# function Quadrotor(;mass=0.5,
#                    J=SMatrix{3,3}(Diagonal([0.0023, 0.0023, 0.004])),
#                    gravity=SVector(0,0,-9.81),
#                    motor_dist=0.1750,
#                    kf=1.0,
#                    km=0.0245,
#                    info=Dict{Symbol,Any}(),
#                    use_quat=false)
#
#     Quadrotor{use_quat,Float64}(13,4,mass,J,inv(J),gravity,motor_dist,kf,km,info)
# end
#
# function dynamics(quad::Quadrotor, x::AbstractVector, u::AbstractVector)
#       # Quaternion representation
#       # Modified from D. Mellinger, N. Michael, and V. Kumar,
#       # "Trajectory generation and control for precise aggressive maneuvers with quadrotors",
#       # In Proceedings of the 12th International Symposium on Experimental Robotics (ISER 2010), 2010.
#
#       ## States: X ∈ R^13; q = [s;v]
#       # x
#       # y
#       # z
#       # q0
#       # q1
#       # q2
#       # q3
#       # xdot
#       # ydot
#       # zdot
#       # omega1
#       # omega2
#       # omega3
#
#       # x = X[1:3]
#       q = normalize(UnitQuaternion(x[4],x[5],x[6],x[7]))
#       # q = Rotations.Quat(x[4],x[5],x[6],x[7])
#       # q = Quaternions.Quaternion(x[4],x[5],x[6],x[7])
#       # q = normalize(q)
#       # q = normalize(Quaternion(view(x,4:7)))
#       # q = view(x,4:7)
#       # normalize!(q)
#       v = view(x,8:10)
#       omega = x[@SVector [11,12,13]]
#
#       # Parameters
#       m = quad.mass # mass
#       J = quad.J # inertia matrix
#       Jinv = quad.Jinv # inverted inertia matrix
#       g = quad.gravity # gravity
#       L = quad.motor_dist # distance between motors
#       kf = quad.kf # 6.11*10^-8;
#       km = quad.km
#
#       w1 = u[1]
#       w2 = u[2]
#       w3 = u[3]
#       w4 = u[4]
#
#       F1 = kf*w1;
#       F2 = kf*w2;
#       F3 = kf*w3;
#       F4 = kf*w4;
#       F = @SVector [0., 0., F1+F2+F3+F4] #total rotor force in body frame
#
#       M1 = km*w1;
#       M2 = km*w2;
#       M3 = km*w3;
#       M4 = km*w4;
#       tau = @SVector [L*(F2-F4), L*(F3-F1), (M1-M2+M3-M4)] #total rotor torque in body frame
#
#       # ẋ[4:7] = 0.5*qmult(q,[0;omega]) #quaternion derivative
#       # qdot = SVector(0.5*q*Quaternion(zero(x[1]), omega))
#       qdot = kinematics(q, ω)
#       ωhat = Quaternion(zero(eltype(omega)), omega[1], omega[2], omega[3])
#       qdot = SVector(0.5*q*ωhat)
#       vdot = g + (1/m)*(q*F) #acceleration in world frame
#       omdot = Jinv*(tau - cross(omega,J*omega)) #Euler's equation: I*ω + ω x I*ω = constraint_decrease_ratio
#       @SVector [v[1], v[2], v[3], qdot[1], qdot[2], qdot[3], qdot[4], vdot[1], vdot[2], vdot[3], omdot[1], omdot[2], omdot[3]]
# end
#
#
# function state_diff(quad::Quadrotor, x, x0)
#       inds = @SVector [4,5,6,7]
#       q = x[inds]
#       q0 = x0[inds]
#       δx = x - x0
#       δq = quat_diff(q, q0)
#       δx = @SVector [δx[1], δx[2], δx[3], δq[1], δq[2], δq[3], δx[8], δx[9], δx[10], δx[11], δx[12], δx[13]]
# end
#
# state_diff(::Quadrotor{false}, x, x0) = x - x0
#
# function quat_diff(q2::SVector{4,T1}, q1::SVector{4,T2}) where {T1,T2}
#     # equivalent to q2 - q1
#     # same as inv(q1)*q2
#     vec = @SVector [2,3,4]
#     s1,v1 = q1[1],-q1[vec]
#     s2,v2 = q2[1], q2[vec]  # needs an inverse
#     # this is q1*q2
#     s1*v2 + s2*v1 + v1 × v2
# end
#
# function quat_diff_jacobian(q::SVector{4,T}) where T
#     w,x,y,z = q
#     x,y,z = -x,-y,-z  # invert q
#     @SMatrix [x  w -z  y;
#               y  z  w -x;
#               z -y  x  w];
# end
#
# function state_diff_jacobian(quad::Quadrotor, x0::SVector{N,T}) where {N,T}
#     inds = @SVector [4,5,6,7]
#     q0 = x0[inds]
#     G = quat_diff_jacobian(q0)
#     I1 = @SMatrix [1 0 0 0 0 0 0 0 0 0 0 0 0;
#                    0 1 0 0 0 0 0 0 0 0 0 0 0;
#                    0 0 1 0 0 0 0 0 0 0 0 0 0;
#                    0 0 0 G[1] G[4] G[7] G[10] 0 0 0 0 0 0;
#                    0 0 0 G[2] G[5] G[8] G[11] 0 0 0 0 0 0;
#                    0 0 0 G[3] G[6] G[9] G[12] 0 0 0 0 0 0;
#                    0 0 0 0 0 0 0 1 0 0 0 0 0;
#                    0 0 0 0 0 0 0 0 1 0 0 0 0;
#                    0 0 0 0 0 0 0 0 0 1 0 0 0;
#                    0 0 0 0 0 0 0 0 0 0 1 0 0;
#                    0 0 0 0 0 0 0 0 0 0 0 1 0;
#                    0 0 0 0 0 0 0 0 0 0 0 0 1.]
#    return I1'
# end
#
# state_diff_jacobian(::Quadrotor{false}, x0::SVector) = I
#
# function TrajectoryOptimization.state_diff_jacobian!(G, model::Quadrotor{true}, Z::Traj)
#     for k in eachindex(Z)
#         G[k] = state_diff_jacobian(model, state(Z[k]))
#     end
# end
#
# @inline state_diff_size(::Quadrotor{false}) = 13
# @inline state_diff_size(::Quadrotor{true}) = 12


struct Quadrotor2{B,R} <: TestRigidBody{B,R}
    n::Int
    m::Int
    mass::Float64
    J::Diagonal{Float64,SVector{3,Float64}}
    Jinv::Diagonal{Float64,SVector{3,Float64}}
    gravity::SVector{3,Float64}
    motor_dist::Float64
    kf::Float64
    km::Float64
    info::Dict{Symbol,Any}
end

Base.size(::Quadrotor2{B,<:UnitQuaternion}) where B = 13,4
Base.size(::Quadrotor2) = 12,4

function Quadrotor2{R}(;use_rot=R<:UnitQuaternion,
        mass=0.5,
        J=Diagonal(@SVector [0.0023, 0.0023, 0.004]),
        gravity=SVector(0,0,-9.81),
        motor_dist=0.1750,
        kf=1.0,
        km=0.0245,
        info=Dict{Symbol,Any}()) where R
    if R <: UnitQuaternion{T,IdentityMap} where T
        if use_rot == true
            use_rot = false
        end
    end
    Quadrotor2{use_rot,R}(13,4,mass,J,inv(J),gravity,motor_dist,kf,km,info)
end

(::Type{Quadrotor2})(;kwargs...) = Quadrotor2{UnitQuaternion{Float64,CayleyMap}}(;kwargs...)

function trim_controls(model::Quadrotor2)
    @SVector fill(-model.gravity[3]*model.mass/4.0, size(model)[2])
end

function forces(model::Quadrotor2, x, u)
    q = orientation(model, x)
    kf = model.kf
    g = model.gravity
    m = model.mass

    w1 = u[1]
    w2 = u[2]
    w3 = u[3]
    w4 = u[4]

    F1 = max(0,kf*w1);
    F2 = max(0,kf*w2);
    F3 = max(0,kf*w3);
    F4 = max(0,kf*w4);
    F = @SVector [0., 0., F1+F2+F3+F4] #total rotor force in body frame

    m*g + q*F # forces in world frame
end

function moments(model::Quadrotor2, x, u)

    kf, km = model.kf, model.km
    L = model.motor_dist

    w1 = u[1]
    w2 = u[2]
    w3 = u[3]
    w4 = u[4]

    F1 = max(0,kf*w1);
    F2 = max(0,kf*w2);
    F3 = max(0,kf*w3);
    F4 = max(0,kf*w4);

    M1 = km*w1;
    M2 = km*w2;
    M3 = km*w3;
    M4 = km*w4;
    tau = @SVector [L*(F2-F4), L*(F3-F1), (M1-M2+M3-M4)] #total rotor torque in body frame
end

function wrenches(model::Quadrotor2, x::SVector, u::SVector)
    F = forces(model, x, u)
    M = moments(model, x, u)
    return F,M

    q = orientation(model, x)
    C = forceMatrix(model)
    mass, g = model.mass, model.gravity

    # Calculate force and moments
    w = max.(u, 0)  # keep forces positive
    fM = forceMatrix(model)*w
    f = fM[1]
    M = @SVector [fM[2], fM[3], fM[4]]
    e3 = @SVector [0,0,1]
    F = mass*g - q*(f*e3)
    return F,M
end

function forceMatrix(model::Quadrotor2)
    kf, km = model.kf, model.km
    L = model.motor_dist
    @SMatrix [
       -kf  -kf  -kf  -kf;
        0    L*kf 0   -L*kf;
       -L*kf 0    L*kf 0;
        km  -km   km  -km;
    ]
end


inertia(model::Quadrotor2, x, u) = model.J
inertia_inv(model::Quadrotor2, x, u) = model.Jinv
mass_matrix(model::Quadrotor2, x, u) = Diagonal(@SVector fill(model.mass,3))

# TrajectoryOptimization.state_diff_size(::Quadrotor{<:UnitQuaternion,false}) = 13
#
# function state_diff(::Quadrotor2{R,false}, x::SVector, x0::SVector) where R
#       return x-x0
# end
#
# function state_diff_jacobian(::Quadrotor2{R,false}, x0::SVector) where R
#       return I
# end
#
# function TrajectoryOptimization.∇²differential(model::Quadrotor2{R,false}, x::SVector,
#             dx::SVector) where R
#       return I*0
# end


############################################################################################
#                                   QUATERNION SLACK
############################################################################################
Base.size(::Quadrotor2{:slack,<:UnitQuaternion}) = 13,5

function dynamics(model::Quadrotor2{:slack,<:UnitQuaternion}, x, u) where D

    r,q,v,ω = parse_state(model, x, false)
    q = q*u[5]

    F = forces(model, x, u)
    τ = moments(model, x, u)
    M = mass_matrix(model, x, u)
    J = inertia(model, x, u)
    Jinv = inertia_inv(model, x, u)

    xdot = v
    qdot = kinematics(q,ω)
    vdot = M\F
    ωdot = Jinv*(τ - ω × (J*ω))

    build_state(model, xdot, qdot, vdot, ωdot)
end

function forces(model::Quadrotor2{:slack,<:UnitQuaternion}, x, u)
    q = orientation(model, x, false)
    q = q*u[5]
    kf = model.kf
    g = model.gravity
    m = model.mass

    w1 = u[1]
    w2 = u[2]
    w3 = u[3]
    w4 = u[4]

    F1 = max(0,kf*w1);
    F2 = max(0,kf*w2);
    F3 = max(0,kf*w3);
    F4 = max(0,kf*w4);
    F = @SVector [0., 0., F1+F2+F3+F4] #total rotor force in body frame

    m*g + q*F # forces in world frame
end

function state_diff(::Quadrotor2{:slack,<:UnitQuaternion}, x::SVector, x0::SVector)
    return x-x0
end

function state_diff_jacobian(model::Quadrotor2{:slack,<:UnitQuaternion}, s::SVector)
    return I
end

function TrajectoryOptimization.∇²differential(model::Quadrotor2{:slack,<:UnitQuaternion},
        x::SVector, dx::SVector) where R
    return I*0
end

function TrajectoryOptimization.inverse_map_jacobian(
        model::Quadrotor2{:slack,<:UnitQuaternion}, x::SVector)
    return I
end

function TrajectoryOptimization.inverse_map_∇jacobian(
        model::Quadrotor2{:slack,<:UnitQuaternion}, x::SVector, b::SVector)
    return I*0
end


############################################################################################
#                                       Lee Quad
############################################################################################

@with_kw struct LeeQuad{B,R,T} <: TestRigidBody{B,R}
    mass::T = 4.34
    J::Diagonal{T,SVector{3,T}} = Diagonal(@SVector [0.0820, 0.0845, 0.1377])
    d::T = 0.315  # motor distance
    cf::T = 8.004e-4 # torque constant
    g::T = -9.81
end

Base.size(::LeeQuad{B,<:UnitQuaternion}) where B = 13,4
Base.size(::LeeQuad) = 12,4

(::Type{<:LeeQuad})(Rot; use_rot=true, kwargs...) = LeeQuad{use_rot,Rot,Float64}(;kwargs...)

inertia(model::LeeQuad, x, u) = model.J
inertia_inv(model::LeeQuad, x, u) = inv(model.J)
mass_matrix(model::LeeQuad, x, u) = Diagonal(@SVector fill(model.mass,3))

function Dynamics.Quadrotor2(model::LeeQuad)
    Dynamics.Quadrotor2{UnitQuaternion{Float64,CayleyMap}}(
        mass=model.mass, J=model.J, motor_dist=model.d, km=model.cf)
end

function forceMatrix(model::LeeQuad)
    d,c = model.d, model.cf
    @SMatrix [
        1  1  1  1;
        0 -d  0  d;
        d  0 -d  0;
       -c  c -c  c;
    ]
end

function wrenches(model::LeeQuad, x::SVector, u::SVector)
    mass,g = model.mass, model.g
    q = orientation(model, x)
    R = rotmat(q)

    # Calculate force and moments
    u = min.(u, 0)  # keep forces negative
    fM = forceMatrix(model)*u
    f = fM[1]
    M = @SVector [fM[2], fM[3], fM[4]]
    e3 = @SVector [0,0,1]
    F = mass*g*e3 - f*R*e3
    return F,M
end

trim_controls(model::LeeQuad) = @SVector fill(model.g*model.mass/4.0, size(model)[2])


############################################################################################
#                                  BODY FRAME LEE QUAD
############################################################################################

@with_kw struct BodyFrameLeeQuad{B,R,T} <: TestRigidBody{B,R}
    mass::T = 4.34
    J::Diagonal{T,SVector{3,T}} = Diagonal(@SVector [0.0820, 0.0845, 0.1377])
    d::T = 0.315  # motor distance
    cf::T = 8.004e-4 # torque constant
    g::T = -9.81
end

Base.size(::BodyFrameLeeQuad{B,<:UnitQuaternion}) where B = 13,4
Base.size(::BodyFrameLeeQuad) = 12,4

(::Type{<:BodyFrameLeeQuad})(Rot; use_rot=true, kwargs...) =
    BodyFrameLeeQuad{use_rot,Rot,Float64}(;kwargs...)

inertia(model::BodyFrameLeeQuad, x, u) = model.J
inertia_inv(model::BodyFrameLeeQuad, x, u) = inv(model.J)
mass_matrix(model::BodyFrameLeeQuad, x, u) = Diagonal(@SVector fill(model.mass,3))


function forceMatrix(model::BodyFrameLeeQuad)
    d,c = model.d, model.cf
    @SMatrix [
        1  1  1  1;
        0 -d  0  d;
        d  0 -d  0;
       -c  c -c  c;
    ]
end

function dynamics(model::BodyFrameLeeQuad, x::SVector, u::SVector)
    # r position in inertial frame
    # q rotation from body to inertial frame
    # v velocity in body frame
    # ω angular velocity in body frame
    r,q,v,ω = parse_state(model, x)

    F,τ = wrenches(model, x, u)
    M = mass_matrix(model, x, u)
    J = inertia(model, x, u)
    Jinv = inertia_inv(model, x, u)

    xdot = q*v
    qdot = kinematics(q,ω)
    vdot = (q\F)/model.mass - ω × v
    ωdot = Jinv*(τ - ω × (J*ω))

    build_state(model, xdot, qdot, vdot, ωdot)
end

function wrenches(model::BodyFrameLeeQuad, x::SVector, u::SVector)
    mass,g = model.mass, model.g
    q = orientation(model, x)
    R = rotmat(q)

    # Calculate force and moments
    u = min.(u, 0)  # keep forces negative
    fM = forceMatrix(model)*u
    f = fM[1]
    M = @SVector [fM[2], fM[3], fM[4]]
    e3 = @SVector [0,0,1]
    F = mass*g*e3 - f*R*e3
    return F,M
end

trim_controls(model::BodyFrameLeeQuad) = @SVector fill(model.g*model.mass/4.0, size(model)[2])
