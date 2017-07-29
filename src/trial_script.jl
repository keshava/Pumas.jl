using DifferentialEquations
using DataFrames
using Distributions
cd(Pkg.dir("PKPDSimulator"))

##########################################
# Internal Functions

const p = zeros(3) # pre-cache p

function generate_η(ω,N)
  [rand(MvNormal(zeros(size(ω,1)),ω)) for i in 1:N]
end

function generate_individual_sol(f,tspan,θ,η,z,i)
 u0 = set_parameters!(p,θ,η,z,i) # from the user
 prob = ODEProblem(f,u0,tspan)
 set_param_values!(prob.f,p) # this is in DiffEqBase: sets values in f
 sol = solve(prob,Tsit5()) # solve the diffeq, return the solution
end

function simulate(f,tspan,θ,ω,z,ϵ=nothing)
  N = maximum(z[:id])
  η = generate_η(ω,N)
  sols = [generate_individual_sol(f,tspan,θ,η[i],z,i) for i in 1:N]
  ϵ != nothing && add_noise!(sols,ϵ)
  sols
end

#########################################
# User Stuff
#########################################
# User definition of the ODE Function

# Option 1: The macro
f = @ode_def_nohes DepotModel begin
  dDepot = -Ka*Depot
  dCentral = Ka*Depot - (CL/V)*Central
end Ka=>2.0 CL=>20.0 V=>100.0

# Option 2: The function
function depot_model(t,u,p,du)
 Depot,Central = u
 Ka,CL,V = p
 du[1] = -Ka*Depot
 du[2] =  Ka*Depot - (CL/V)*Central
end
f = ParameterizedFunction(depot_model,[2.0,20.0,100.0])

###########################################
# User definition of the set_parameters! function

function set_parameters!(p,θ,η,z,i)
  wt,sex = first(z[1+(i-1)*20,:][:wt]),first(z[1+(i-1)*20,:][:sex])
  Ka = θ[1]
  CL = θ[2]*((wt/70)^0.75)*(θ[4]^sex)*exp(η[1])
  V  = θ[3]*exp(η[2])
  p[1] = Ka; p[2] = CL; p[3] = V
  u0 = [float(first(z[1+(i-1)*20,:][:amt])),0.0]
end

############################################
# Population setup

θ = [2.0,3.0,10.0,1.0]
ω = [0.05 0.0
     0.0 0.2]
tspan = (0.0,19.0)
z = readtable("examples/data1.csv")

#############################################
# Call simulate

sols = simulate(f,tspan,θ,ω,z)

using Plots; plotly()
plot(sols[1])
for i in 2:length(sols); plot!(sols[i]); end
plot!(sols[40])
