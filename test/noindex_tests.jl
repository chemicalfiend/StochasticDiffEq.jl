using StochasticDiffEq, Test, Random, DiffEqNoiseProcess,
        RecursiveArrayTools, LinearAlgebra
Random.seed!(100)

struct NoIndexArray{T, N} <: AbstractArray{T, N}
    x::Array{T, N}
end
Base.size(x::NoIndexArray) = size(x.x)
Base.axes(x::NoIndexArray) = axes(x.x)
Base.similar(x::NoIndexArray, dims::Union{Integer, AbstractUnitRange}...) = NoIndexArray(similar(x.x, dims...))
Base.copyto!(x::NoIndexArray, y::NoIndexArray) = NoIndexArray(copyto!(x.x, y.x))
Base.copy(x::NoIndexArray) = NoIndexArray(copy(x.x))
Base.zero(x::NoIndexArray) = NoIndexArray(zero(x.x))
Base.fill!(x::NoIndexArray, y) = NoIndexArray(fill!(x.x, y))
Base.mapreduce(f, op, x::NoIndexArray; kwargs...) = mapreduce(f, op, x.x; kwargs...)
Base.any(f::Function, x::NoIndexArray; kwargs...) = any(f, x.x; kwargs...)
Base.all(f::Function, x::NoIndexArray; kwargs...) = all(f, x.x; kwargs...)
Base.:(==)(x::NoIndexArray, y::NoIndexArray) = x.x == y.x

struct NoIndexStyle{N} <: Broadcast.AbstractArrayStyle{N} end
NoIndexStyle(::Val{N}) where N = NoIndexStyle{N}()
NoIndexStyle{M}(::Val{N}) where {N,M} = NoIndexStyle{N}()
Base.BroadcastStyle(::Type{<:NoIndexArray{T,N}}) where {T,N} = NoIndexStyle{N}()
Base.similar(bc::Base.Broadcast.Broadcasted{NoIndexStyle{N}}, ::Type{ElType}) where {N, ElType} = NoIndexArray(similar(Array{ElType, N}, axes(bc)))
Base.Broadcast._broadcast_getindex(x::NoIndexArray, i) = x.x[i]
Base.Broadcast.extrude(x::NoIndexArray) = x

@inline function Base.copyto!(dest::NoIndexArray, bc::Base.Broadcast.Broadcasted{<:NoIndexStyle})
    axes(dest) == axes(bc) || throwdm(axes(dest), axes(bc))
    bc′ = Base.Broadcast.preprocess(dest, bc)
    dest′ = dest.x
    @simd for I in eachindex(bc′)
        @inbounds dest′[I] = bc′[I]
    end
    return dest
end
Base.show_vector(io::IO, x::NoIndexArray) = Base.show_vector(io, x.x)

Base.show(io::IO, x::NoIndexArray) = (print(io, "NoIndexArray");show(io, x.x))
function Base.show(io::IO, ::MIME"text/plain", x::NoIndexArray)
    println(io, Base.summary(x), ":")
    Base.print_array(io, x.x)
end

prob = SDEProblem((du, u, p, t)->copyto!(du, u),(du, u, p, t)->copyto!(du, u),NoIndexArray(ones(10, 10)),(0.0,1.0))
algs = [SOSRI(), SOSRA()]
DiffEqNoiseProcess.wiener_randn!(rng::AbstractRNG,rand_vec::NoIndexArray) = randn!(rng,rand_vec.x)

for alg in algs
  sol = @test_nowarn solve(prob, alg)
  @test_nowarn sol(0.1)
  @test_nowarn sol(similar(prob.u0), 0.1)
end


struct CustomArray{T, N}
    x::Array{T, N}
end
Base.size(x::CustomArray) = size(x.x)
Base.axes(x::CustomArray) = axes(x.x)
Base.ndims(x::CustomArray) = ndims(x.x)
Base.ndims(::Type{<:CustomArray{T,N}}) where {T,N} = N
Base.zero(x::CustomArray) = CustomArray(zero(x.x))
Base.zero(::Type{<:CustomArray{T,N}}) where {T,N} = CustomArray(zero(Array{T,N}))
Base.similar(x::CustomArray, dims::Union{Integer, AbstractUnitRange}...) = CustomArray(similar(x.x, dims...))
Base.copyto!(x::CustomArray, y::CustomArray) = CustomArray(copyto!(x.x, y.x))
Base.copy(x::CustomArray) = CustomArray(copy(x.x))
Base.length(x::CustomArray) = length(x.x)
Base.isempty(x::CustomArray) = isempty(x.x)
Base.eltype(x::CustomArray) = eltype(x.x)
Base.zero(x::CustomArray) = CustomArray(zero(x.x))
Base.fill!(x::CustomArray, y) = CustomArray(fill!(x.x, y))
Base.getindex(x::CustomArray, i) = getindex(x.x, i)
Base.setindex!(x::CustomArray, v, idx) = setindex!(x.x, v, idx)
Base.mapreduce(f, op, x::CustomArray; kwargs...) = mapreduce(f, op, x.x; kwargs...)
Base.any(f::Function, x::CustomArray; kwargs...) = any(f, x.x; kwargs...)
Base.all(f::Function, x::CustomArray; kwargs...) = all(f, x.x; kwargs...)
Base.similar(x::CustomArray, t) = CustomArray(similar(x.x, t))
Base.:(==)(x::CustomArray, y::CustomArray) = x.x == y.x
Base.:(*)(x::Number, y::CustomArray) = CustomArray(x*y.x)
Base.:(/)(x::CustomArray, y::Number) = CustomArray(x.x/y)
LinearAlgebra.norm(x::CustomArray) = norm(x.x)

struct CustomStyle{N} <: Broadcast.BroadcastStyle where {N} end
CustomStyle(::Val{N}) where N = CustomStyle{N}()
CustomStyle{M}(::Val{N}) where {N,M} = NoIndexStyle{N}()
Base.BroadcastStyle(::Type{<:CustomArray{T,N}}) where {T,N} = CustomStyle{N}()
Broadcast.BroadcastStyle(::CustomStyle{N}, ::Broadcast.DefaultArrayStyle{0}) where {N} = CustomStyle{N}()
Base.similar(bc::Base.Broadcast.Broadcasted{CustomStyle{N}}, ::Type{ElType}) where {N, ElType} = CustomArray(similar(Array{ElType, N}, axes(bc)))
Base.Broadcast._broadcast_getindex(x::CustomArray, i) = x.x[i]
Base.Broadcast.extrude(x::CustomArray) = x
Base.Broadcast.broadcastable(x::CustomArray) = x

@inline function Base.copyto!(dest::CustomArray, bc::Base.Broadcast.Broadcasted{<:CustomStyle})
    axes(dest) == axes(bc) || throwdm(axes(dest), axes(bc))
    bc′ = Base.Broadcast.preprocess(dest, bc)
    dest′ = dest.x
    @simd for I in 1:length(dest′)
        @inbounds dest′[I] = bc′[I]
    end
    return dest
end
@inline function Base.copy(bc::Base.Broadcast.Broadcasted{<:CustomStyle})
    bcf = Broadcast.flatten(bc)
    x = find_x(bcf)
    data = zeros(eltype(x), size(x))
    @inbounds @simd for I in 1:length(x)
        data[I] = bcf[I]
    end
    return CustomArray(data)
end
find_x(bc::Broadcast.Broadcasted) = find_x(bc.args)
find_x(args::Tuple) = find_x(find_x(args[1]), Base.tail(args))
find_x(x) = x
find_x(::Any, rest) = find_x(rest)
find_x(x::CustomArray, rest) = x.x

RecursiveArrayTools.recursive_unitless_bottom_eltype(x::CustomArray) = eltype(x)
RecursiveArrayTools.recursivecopy!(dest::CustomArray, src::CustomArray) = copyto!(dest, src)
RecursiveArrayTools.recursivecopy(x::CustomArray) = copy(x)
RecursiveArrayTools.recursivefill!(x::CustomArray, a) = fill!(x, a)
DiffEqNoiseProcess.wiener_randn!(rng::AbstractRNG,rand_vec::CustomArray) = randn!(rng,rand_vec.x)

Base.show_vector(io::IO, x::CustomArray) = Base.show_vector(io, x.x)

Base.show(io::IO, x::CustomArray) = (print(io, "CustomArray");show(io, x.x))
function Base.show(io::IO, ::MIME"text/plain", x::CustomArray)
    println(io, Base.summary(x), ":")
    Base.print_array(io, x.x)
end

prob = SDEProblem((du, u, p, t)->copyto!(du, u),(du, u, p, t)->copyto!(du, u), CustomArray(ones(10)), (0.0,1.0))

for alg in algs
    sol_ca = @test_nowarn solve(prob, alg)
    @test_nowarn sol_ca(0.1)
    @test_nowarn sol_ca(similar(prob.u0), 0.1)
  end