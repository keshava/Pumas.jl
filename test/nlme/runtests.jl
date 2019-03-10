using Test, SafeTestsets
using PuMaS, LinearAlgebra, Optim

if group == "All" || group == "NLME_NOBAYES"
  @time @safetestset "Non-Bayesian models" begin
    @time @safetestset "Simple Model"                                begin include("simple_model.jl")        end
    @time @safetestset "Simple Model with T-distributed error model" begin include("simple_model_tdist.jl")  end
    @time @safetestset "Simple Model disagnostics"                   begin include("simple_model_dignostics.jl")  end
    @time @safetestset "Theophylline NLME.jl"                        begin include("theop_nlme.jl")          end
    @time @safetestset "Theophylline"                                begin include("theophylline.jl")        end
    @time @safetestset "Wang"                                        begin include("wang.jl")                end
    @time @safetestset "Poisson"                                     begin include("poisson_model.jl")       end
  end
end

if group == "All" || group == "NLME_BAYES"
  @time @safetestset "Bayesian models"                               begin include("bayes.jl")       end
end
