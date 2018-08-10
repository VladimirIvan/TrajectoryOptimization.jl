using Plots

#TODO finish
function plot_cost(results::ResultsCache)
    index_outerloop = find(x -> x == 1, results.iter_type)
end
"""
@(SIGNATURES)

Generate an animation of a trajectory as it evolves during a solve
"""
function trajectory_animation(results::ResultsCache;traj::String="state",ylim=[-10;10],title::String="Trajectory Evolution",filename::String="trajectory.gif",fps::Int=1)::Void
    anim = @animate for i=1:results.termination_index
        if traj == "state"
            t = results.result[i].X'
        elseif traj == "control"
            t = results.result[i].U'
        end
        plot(t,ylim=(ylim[1],ylim[2]),size=(200,200),label="",width=1,title=title)
        if results.iter_type[i] == 2
            plot!(xlabel="Infeasible->Feasible") # note the transition from an infeasible to feasible solve
        end
    end

    path = joinpath(Pkg.dir("TrajectoryOptimization"),filename)
    gif(anim,path,fps=fps)
    return nothing
end
