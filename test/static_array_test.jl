using Base.Test

using PKPDSimulator, Distributions, NamedTuples, StaticArrays


# Read the data# Read the data
data = process_data(joinpath(Pkg.dir("PKPDSimulator"),"examples/data1.csv"),
                    [:sex,:wt,:etn],separator=',')
# add a small epsilon to time 0 observations
for subject in data.subjects
    obs1 = subject.observations[1]
    if obs1.time == 0
        subject.observations[1] = PKPDSimulator.Observation(sqrt(eps()), obs1.val, obs1.cmt)
    end
end


## parameters
mdsl = @model begin
    @param begin
        θ ∈ VectorDomain(4, lower=zeros(4), init=ones(4))
        Ω ∈ PSDDomain(2)
        Σ ∈ RealDomain(lower=0.0, init=1.0)
    end

    @random begin
        η ~ MvNormal(Ω)
    end

    @data_cov sex wt etn

    @collate begin
        Ka = θ[1]
        CL = θ[2] * ((wt/70)^0.75) * (θ[4]^sex) * exp(η[1])
        V  = θ[3] * exp(η[2])
    end

    @dynamics begin
        dDepot   = -Ka*Depot
        dCentral =  Ka*Depot - (CL/V)*Central
    end

    @post begin
        conc = Central / V
    end

    @error begin
        conc = Central / V
        dv ~ Normal(conc, conc*Σ)
    end
end

mstatic = PKPDModel(ParamSet(@NT(θ = VectorDomain(4, lower=zeros(4), init=ones(4)),
                              Ω = PSDDomain(2),
                              Σ = RealDomain(lower=0.0, init=1.0))),
                 (_param) -> RandomEffectSet(@NT(η = RandomEffect(MvNormal(_param.Ω)))),
                 (_param, _random, _data_cov) -> @NT(Ka = _param.θ[1],
                                                     CL = _param.θ[2] * ((_data_cov.wt/70)^0.75) *
                                                          (_param.θ[4]^_data_cov.sex) * exp(_random.η[1]),
                                                     V  = _param.θ[3] * exp(_random.η[2])),
                 (_param, _random, _data_cov,_collate,t) -> @SVector([0.0,0.0]),
                 function depot_model(u,p,t)
                     Depot,Central = u
                     @SVector [-p.Ka*Depot,
                                p.Ka*Depot - (p.CL/p.V)*Central
                              ]
                 end,
                 (_param, _random, _data_cov,_collate,_odevars,t) -> @NT(conc = _odevars[2] / _collate.V),
                 (_param, _random, _data_cov,_collate,_odevars,t) -> (conc = _odevars[2] / _collate.V;
                                                     @NT(dv = Normal(conc, conc*_param.Σ))))



x0 = init_param(mdsl)
y0 = init_random(mdsl, x0)

subject = data.subjects[1]

@test pkpd_likelihood(mdsl,subject,x0,y0,abstol=1e-12,reltol=1e-12) ≈ pkpd_likelihood(mstatic,subject,x0,y0,abstol=1e-12,reltol=1e-12)

@test (srand(1); map(x -> x.dv, pkpd_simulate(mdsl,subject,x0,y0,abstol=1e-12,reltol=1e-12))) ≈
      (srand(1); map(x -> x.dv, pkpd_simulate(mstatic,subject,x0,y0,abstol=1e-12,reltol=1e-12)))

@test map(x -> x.conc, pkpd_post(mdsl,subject,x0,y0,abstol=1e-12,reltol=1e-12)) ≈
      map(x -> x.conc, pkpd_post(mstatic,subject,x0,y0,abstol=1e-12,reltol=1e-12))

post_dsl = pkpd_postfun(mdsl, subject, x0, y0,abstol=1e-12,reltol=1e-12)
post_static = pkpd_postfun(mstatic, subject, x0, y0,abstol=1e-12,reltol=1e-12)

@test post_dsl(1).conc ≈ post_static(1).conc




#
mstatic2 = PKPDModel(ParamSet(@NT(θ = VectorDomain(3, lower=zeros(3), init=ones(3)),
                              Ω = PSDDomain(2))),
                 (_param) -> RandomEffectSet(@NT(η = RandomEffect(MvNormal(_param.Ω)))),
                 (_param, _random, _data_cov) -> @NT(Ka = _param.θ[1],
                                                     CL = _param.θ[2] * exp(_random.η[1]),
                                                     V  = _param.θ[3] * exp(_random.η[2])),
                 (_param, _random, _data_cov,_collate,t) -> @SVector([0.0,0.0]),
                 function depot_model(u,p,t)
                     Depot,Central = u
                     @SVector [-p.Ka*Depot,
                                p.Ka*Depot - (p.CL/p.V)*Central
                              ]
                 end,
                 (_param, _random, _data_cov,_collate,_odevars,t) -> @NT(conc = _odevars[2] / _collate.V),
                 (_param, _random, _data_cov,_collate,_odevars,t) -> ())



subject = build_dataset(amt=[10,20], ii=[24,24], addl=[2,2], ss=[1,2], time=[0,12],  cmt=[2,2])

x0 = @NT(θ = [
              1.5,  #Ka
              1.0,  #CL
              30.0 #V
              ],
         Ω = eye(2))
y0 = @NT(η = zeros(2))

p = pkpd_post(mstatic2,subject,x0,y0;obstimes=[i*12+1e-12 for i in 0:1],abstol=1e-12,reltol=1e-12)
@test [1000*x.conc for x in p] ≈ [605.3220736386598;1616.4036675452326]