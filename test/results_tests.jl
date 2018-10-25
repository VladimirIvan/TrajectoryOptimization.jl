using Test
# Unconstrained Results Constructors
n = rand(1:10)
m = rand(1:10)
N = rand(10:10:100)
r = TrajectoryOptimization.UnconstrainedVectorResults(n,m,N)
@test (length(r.X[1]),length(r.X)) == (n,N)
@test (length(r.U[1]),length(r.U)) == (m,N)
@test (size(r.K[1])...,length(r.K)) == (m,n,N)

r2 = TrajectoryOptimization.UnconstrainedVectorResults(n,m,N)
r.X[1] .= 1:n
copyto!(r2.X,r.X)
@test r2.X[1] == 1:n  # Make sure the copy worked
r2.X[1][1] = 4
@test r.X[1][1] == 1  # Make sure the copies aren't linked


# Static Results
rs = TrajectoryOptimization.UnconstrainedStaticResults(n,m,N)
@test length(rs.X) == N
@test length(rs.X[1]) == n
@test length(rs.U) == N
@test length(rs.U[1]) == m
@test size(rs.K[1]) == (m,n)

# Constrained Results
p = rand(1:5)
p_N = rand(1:5)
r = ConstrainedVectorResults(n,m,p,N,p_N)
@test (length(r.C[1]),length(r.C)) == (p,N)
@test (size(r.Iμ[1])...,length(r.Iμ)) == (p,p,N)
