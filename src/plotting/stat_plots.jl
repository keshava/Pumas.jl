################################################################################
#                          Covariate plots versus ηs                           #
################################################################################
"""
    etacov(
        res::PumasModel;
        cvs = [],
        continuoustype = :scatter,
        discretetype = :boxplot,
        catmap = NamedTuple()
    )

Plots the covariates of the model (defaults to all, can be specified by `cvs`)
against the `η`s (also called the `ebe`s).

It works differently for categorical and continuous covariates.  For categorical
covariates, a box plot will be generated by default
(configurable by `discretetype`);
for continuous covariates, a scatter plot will be generated
(configurable by `continuoustype`).

Whether an array is categorical or not is determined by the function [`iscategorical`](@ref),
but you can override this automated heuristic by providing a `NamedTuple` of the
form `(colname = true)` to set colname to be treated as categorical, or `false`
for it to be treated as continuous.
"""
@userplot EtaCov

@recipe function f(
            ec::EtaCov;
            cvs = [],
            etas = [],
            continuoustype = :scatter,
            discretetype = :boxplot,
            catmap = NamedTuple(),
        )

    @assert length(ec.args) == 1
    @assert eltype(ec.args) <: Union{PumasModel, FittedPumasModel}
    @assert(isempty(catmap) || catmap isa NamedTuple)

    legend --> :none

    # extract the provided model
    res = ec.args[1]

    # easy API for use, why bother with nested data structures?
    df = DataFrame(inspect(res))

    # retrieve all covariate names.  Here, it's assumed they're the same for each Subject.
    allcovnames = res.data[1].covariates |> keys

    covnames = isempty(cvs) ? allcovnames : cvs
    etanames = isempty(etas) ? [:ebe_1] : etas

    # get the index number, to find the relevant `η` (eta)
    covindices = findfirst.((==).(covnames), Ref(allcovnames))

    # create a named tuple
    calculated_iterable = (; zip(covnames,iscategorical.(getindex.(Ref(df), !, covnames)))...)

    # merge the category map, such that it takes priority over the automatically calculated values.
    covtypes = merge(calculated_iterable, catmap)

    # use our good layout function
    layout --> good_layout(length(covnames) * length(etanames))

    i = 1

    for covname in covnames, etaname in etanames

        covtype = covtypes[covname]

        # the reference zero line

        @series begin
            # can tweak this, or allow user to
            seriestype := covtype ? :boxplot : :scatter
            subplot := i

            title := string(covname)
            ylabel := string(etaname) # do we need this?

            (df[:, covname], df[:, etaname])
        end

        @series begin

            seriestype := :hline
            subplot := i
            color := :black
            title := string(covname)
            ylabel := string(etaname) # do we need this?

            linestyle --> :dash

            ([0.0]) # zero-line
        end

        if !covtype # continuous
            try
                # check that the covariate has no duplicate x-values!
                # There should be a more efficient way using `foldl`, but that's
                # a bit opaque.
                @assert unique(df[:, covname]) == length(df[!, covname])

                @series begin
                    seriestype := :loess # defined by DataInterpolations.jl
                    label := "LOESS fit" # not used anyway, but in case we decide to include it
                    ylabel := string(etaname) # do we need this?

                    subplot := i

                    (df[:, covname], df[:, etaname])
                end

            catch err
                if err isa AssertionError
                    @warn("The covariate `$covname` cannot be fitted to a curve, as it has multiple occurrences of the same value.")
                else
                    rethrow(err)
                end
            end # try-catch
        end # if

        i += 1
    end # loop

    primary := false

end

################################################################################
#                       Covariate plots versus residuals                       #
################################################################################

@userplot ResPlot

@recipe function f(
            rp::ResPlot;
            vs = [], # could be any name in the df
            continuoustype = :scatter,
            discretetype = :boxplot,
            panel = [],
            catmap = NamedTuple(),
            _resname = :wres,
        )

    @assert length(rp.args) == 1
    @assert eltype(rp.args) <: Union{PumasModel, FittedPumasModel}
    @assert(isempty(catmap) || catmap isa NamedTuple)

    legend --> :none

    res = rp.args[1]

    df = DataFrame(inspect(res))

    # hack to get dvs, will remove when this is implemented in the dataframe
    df[!, :dv] = vcat((res.data .|> x -> x.observations.dv)...)

    allcovnames = res.data[1].covariates |> keys

    varnames = isempty(vs) ? allcovnames : vs # here, it's assumed covariates are the same for all Subjects.

    varindices = findfirst.((==).(varnames), Ref(names(df))) # get the index number, to find the relevant `η` (eta)

    calculated_iterable = (;zip(varnames,iscategorical.(getindex.(Ref(df), !, varnames)))...)

    vartypes = merge(calculated_iterable, catmap)

    layout --> good_layout(length(varindices))

    for (i, varname) in zip(eachindex(varnames), varnames)
        @series begin
            seriestype := vartypes[varname] ? :boxplot : :scatter
            subplot := i

            # title := string(varname)
            ylabel --> "CWRES"
            xlabel --> string(varname)

            (df[:, varname], df[:, _resname])
        end
        @series begin

            seriestype := :hline
            subplot := i
            color := :black
            # title := string(varname)
            ylabel --> "CWRES"
            xlabel --> string(varname)

            linestyle --> :dash

            ([0.0]) # zero-line
        end
    end

    primary := false

end
