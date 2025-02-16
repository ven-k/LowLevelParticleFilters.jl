abstract type AbstractFilteringSolution end

"""
    KalmanFilteringSolution{Tx,Txt,TR,TRt,Tll} <: AbstractFilteringSolution

# Fields
- `x`: predictions ``x(t+1|t)``
- `xt`: filtered estimates ``x(t|t)``
- `R`: predicted covariance matrices ``R(t+1|t)``
- `Rt`: filter covariances ``R(t|t)``
- `ll`: loglikelihood
"""
struct KalmanFilteringSolution{F,Tu,Ty,Tx,Txt,TR,TRt,Tll} <: AbstractFilteringSolution
    f::F
    u::Tu
    y::Ty
    x::Tx
    xt::Txt
    R::TR
    Rt::TRt
    ll::Tll
end

@recipe function plot(timevec::AbstractVector{<:Real}, sol::KalmanFilteringSolution; plotx = true, plotxt=true, plotu=true, ploty=true)
    nx, nu, ny = length(sol.x[1]), length(sol.u[1]), length(sol.y[1])
    layout --> nx*(plotx || plotxt) + plotu*nu + ploty*ny
    plotx && @series begin
        label --> ["x$(i)(t|t-1)" for i in 1:nx] |> permutedims
        subplot --> (1:nx)'
        timevec, reduce(hcat, sol.x)'
    end
    plotxt && @series begin
        label --> ["x$(i)(t|t)" for i in 1:nx] |> permutedims
        subplot --> (1:nx)'
        timevec, reduce(hcat, sol.xt)'
    end
    plotu && nu > 0 && @series begin
        label --> ["u$(i)" for i in 1:nu] |> permutedims
        subplot --> (1:nu)' .+ nx*(plotx || plotxt)
        timevec, reduce(hcat, sol.u)'
    end
    ploty && @series begin
        label --> ["y$(i)" for i in 1:ny] |> permutedims
        subplot --> (1:ny)' .+ (nx*(plotx || plotxt) + nu*plotu)
        timevec, reduce(hcat, sol.y)'
    end
end

@recipe function plot(sol::KalmanFilteringSolution)
    timevec = 1:length(sol.y)
    @series timevec, sol
end

"""
    ParticleFilteringSolution{F, Tu, Ty, Tx, Tw, Twe, Tll} <: AbstractFilteringSolution

# Fields:
- `f`: Filter
- `u`: Input
- `y`: Output / measurements
- `x`: Particles
- `w`: Weights (log space)
- `we`: Weights (exponentiated)
- `ll`: Log likelihood
"""
struct ParticleFilteringSolution{F,Tu,Ty,Tx,Tw,Twe,Tll} <: AbstractFilteringSolution
    f::F
    u::Tu
    y::Ty
    x::Tx
    w::Tw
    we::Twe
    ll::Tll
end

function td_getargs(sol::ParticleFilteringSolution, d::Int=1)
    (; f,x,w,u,y) = sol
    f,x,w,u,y,d
end

td_getargs(f,x,w,u,y,d::Int=1) = f,x,w,u,y,d

@recipe function plot(sol::ParticleFilteringSolution; nbinsy=30, xreal=nothing, dim=nothing)
    if dim === nothing || dim === (:)
        (; f,x,w,u,y) = sol
        p = parameters(f)
        N,T = size(x)
        D = length(x[1])
        P = length(y[1])
        if sum(w) ≉ T
            w = exp.(w)
            w ./= sum(w, dims=1)
        end

        w = vec(w)
        vx = vec(x)
        background_color --> :black

        layout := D+P
        label := ""
        markercolor --> :cyan
        title --> reshape([["State $d" for d = 1:D];["Measurement $d" for d = 1:P]], 1, :)
        for d = 1:D
            subplot := d
            @series begin
                seriestype := :histogram2d
                bins --> (0.5:1:T+0.5,nbinsy)
                weights --> w
                repeat((1:T)' .-0.5,N)[:], vec(getindex.(vx,d))
            end
            xreal === nothing || @series begin
                seriestype := :scatter
                1:T, getindex.(xreal,d)
            end
        end
        yhat = measurement(f).(x, permutedims(u), Ref(p), (1:T)') |> vec
        for d = 1:P
            subplot := d+D
            @series begin
                seriestype := :histogram2d
                bins --> (0.5:1:T+0.5,nbinsy)
                weights --> w
                repeat((1:T)' .-0.5,N)[:], vec(getindex.(yhat,d))
            end
            @series begin
                seriestype := :scatter
                1:T, getindex.(y,d)
            end
        end
    else
        (; f,x,w,u,y) = sol
        d = dim
        N,T = size(x)
        D = length(x[1])
        P = length(y[1])
    
        if sum(w) ≉ T
            w = exp.(w)
            w ./= sum(w, dims=1)
        end
    
        label := ""
        markercolor --> :cyan
        if d <= D
            @series begin
                seriestype := :histogram2d
                bins --> (0.5:1:T+0.5,nbinsy)
                weights --> vec(w)
                repeat((1:T)' .-0.5,N)[:], vec(getindex.(x,d))
            end
            xreal === nothing || @series begin
                seriestype := :scatter
                1:T, getindex.(xreal,d)
            end
        else
            d -= D
            yhat = measurement(f).(x,u',0) |> vec
            @series begin
                seriestype := :histogram2d
                bins --> (0.5:1:T+0.5,nbinsy)
                weights --> vec(w)
                repeat((1:T)' .-0.5,N)[:], vec(getindex.(yhat,d))
            end
            @series begin
                seriestype := :scatter
                1:T, getindex.(y,d)
            end
    
        end
    end
end

# function Base.getproperty(sol::AbstractFilteringSolution, s::Symbol)
#     s ∈ fieldnames(typeof(sol)) && return getfield(sol, s)
#     if s === :retcode
#         return :success
#     elseif s === :interp
#         return nothing
#     elseif s === :dense
#         return false
#     elseif s === :prob
#         return sol
#     elseif s === :t
#         return 1:length(getfield(sol, :x))
#     elseif s === :tslocation
#         return 0
#     else
#         throw(ArgumentError("$(typeof(sol)) has no property named $s"))
#     end
# end

# SciMLBase.has_syms(pf::AbstractFilter) = false