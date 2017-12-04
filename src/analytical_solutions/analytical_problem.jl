struct PKPDAnalyticalProblem{uType,tType,isinplace,F,S,C} <: AbstractAnalyticalProblem{uType,tType,isinplace}
  f::F
  ss::S
  u0::uType
  tspan::Tuple{tType,tType}
  callback::C
  function PKPDAnalyticalProblem{iip}(f,u0,tspan,ss = nothing;
           callback = nothing) where {iip}
    new{typeof(u0),promote_type(map(typeof,tspan)...),iip,
        typeof(f),typeof(ss),typeof(callback)}(f,ss,u0,tspan,callback)
  end
end

function PKPDAnalyticalProblem(f,u0,tspan,args...;kwargs...)
  iip = DiffEqBase.isinplace(f,7)
  PKPDAnalyticalProblem{iip}(f,u0,tspan,args...;kwargs...)
end

export PKPDAnalyticalProblem