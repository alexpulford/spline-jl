module Splines

using ModernGL
using CSyntax
using CSyntax.CStatic
using LinearAlgebra

using ..Buffers

export Point, BSpline, SplineType

mutable struct Point
    x::Float64
    y::Float64
    z::Float64
end

mutable struct BSpline
    control_points::Array{Point}
    knots::Array{Float64}

    curve::Buffer

    hovered::Int32
    selected::Int32
end

function to_vec(p::Point)
    return Float64[p.x, p.y, p.z]
end

function Base.:+(x::Point, y::Point)
    return Point(x.x+y.x, x.y+y.y, x.z+y.z)
end

function Base.:-(x::Point, y::Point)
    return Point(x.x-y.x, x.y-y.y, x.z-y.z)
end

function Base.:*(x::Point, y::Float64)
    return Point(x.x*y, x.y*y, x.z*y)
end

Base.:*(x::Float64, y::Point) = (y*x)

function is_finite(f)
    if(f == Inf || f == -Inf || isnan(f))
        return false
    end
    return true
end

function N(s::BSpline, i::Real, p::Real, x::Real)::Float64
    if p == 0
        return s.knots[i] <= x && x < s.knots[i + 1] ? 1.0 : 0.0;
    end

    a = (x - s.knots[i]) / (s.knots[i + p] - s.knots[i]);
    a = is_finite(a) ? a : 0;
    b = (s.knots[i + p + 1] - x) / (s.knots[i + p + 1] - s.knots[i + 1]);
    b = is_finite(b) ? b : 0;

    return a * N(s, i, p - 1, x) + b * N(s, i + 1, p - 1, x);
end

function get_influence(s::BSpline, i::Int64, f)::Vector{Point}
    out = Vector{Point}()
    for f_ = 0:(f)
        t = f_
        t /= (f+0.001)
        push!(out, Point(t,  N(s, i, 3, t), 0))
    end
    return out
end

function S(s::BSpline, t::Real)::Point
    a = Point(0,0,0)
    for i = 1:(size(s.control_points, 1))
        a += N(s, i, 3, t) * s.control_points[i];
    end
    return a;
end

function generate_points(s::BSpline, steps)
    m = size(s.knots, 1)
    d = m - size(s.control_points, 1)
    
    tmin = s.knots[d];
    tmax = s.knots[m-d+1];
    out = Vector{Point}()
    for i = 0:(steps)
        t = (tmax-tmin)*(i/steps) + tmin;
        push!(out, S(s, t))
    end
    return out
end

function generate_circle(steps)
    out = Vector{Point}()
    for i = 0:(steps)
        t = (2*pi)*(i/(steps-1));
        push!(out, Point(sin(t),cos(t), 0))
    end
    return out
end

function generate_circle_h(steps)
    out = Vector{Point}()
    for i = 0:(steps)
        t = (2*pi)*(i/(steps-1));
        push!(out, Point(sin(t), 0, cos(t)))
    end
    return out
end

function get_geometry(s::BSpline, points::Vector{Point}, w::GLfloat)
    out = GLfloat[]
    original = GLfloat[1, 1, 0]
    selected = GLfloat[1, 0, 1]
    hovered = GLfloat[0, 1, 1]
    c = original
    z = nothing
    zi = nothing
    zj = nothing

    r = 10
    rtheta = (pi/(2*r -1))

    a::Point = points[1]
    for t in 1:r
        theta = pi*(t/r)
        for b in points[2:end]
            ab = b - a
            h = normalize(cross(to_vec(a), to_vec(b)))
            v = normalize(cross(to_vec(ab), h))

            n = (sin(theta)*v + cos(theta)*h)
            j = w*n
            i = rtheta*w*normalize(cross(to_vec(ab), n))

            va = to_vec(a)
            vb = to_vec(b)
            
            h = GLfloat[
                (va+i+j)..., c..., (i+j)...,
                (vb+i+j)..., c..., (i+j)...,
                (va-i+j)..., c..., (-i+j)...,
                (va-i+j)..., c..., (-i+j)...,
                (vb-i+j)..., c..., (-i+j)...,
                (vb+i+j)..., c..., (i+j)...,
            
                (va+i-j)..., c..., (i-j)...,
                (vb+i-j)..., c..., (i-j)...,
                (va-i-j)..., c..., (-i-j)...,
                (va-i-j)..., c..., (-i-j)...,
                (vb-i-j)..., c..., (-i-j)...,
                (vb+i-j)..., c..., (i-j)...,

            ]
            append!(out, h)

            if(z != nothing)
                vz = to_vec(z)
                h = GLfloat[
                    (va+i+j)..., c..., (i+j)...,
                    (vz+zi+zj)..., c..., (zi+zj)...,
                    (va-i+j)..., c..., (-i+j)...,
                    (va-i+j)..., c..., (-i+j)...,
                    (vz-zi+zj)..., c..., (-zi+zj)...,
                    (vz+zi+zj)..., c..., (zi+zj)...,
                
                    (va+i-j)..., c..., (i-j)...,
                    (vz+zi-zj)..., c..., (zi-zj)...,
                    (va-i-j)..., c..., (-i-j)...,
                    (va-i-j)..., c..., (-i-j)...,
                    (vz-zi-zj)..., c..., (-zi-zj)...,
                    (vz+zi-zj)..., c..., (zi-zj)...,
                ]

                append!(out, h)
            end

            z = b
            zi = i
            zj = j
            a = b
        end
    end
    w*=2
    white = [1, 1, 1]
    x = [w, 0, 0]
    y = [0, w, 0]
    z = [0, 0, w]
    idx::Int32 = 0
    for c_p in s.control_points
        idx += 1
        if(idx == s.selected)
            c = selected
        elseif(idx == s.hovered)
            c = hovered
        else 
            c = white
        end

        p = to_vec(c_p)
        h = GLfloat[

            (p+z-y+x)..., c..., x...,
            (p-z+y+x)..., c..., x...,
            (p-z-y+x)..., c..., x...,
            (p+z-y+x)..., c..., x...,
            (p-z+y+x)..., c..., x...,
            (p+z+y+x)..., c..., x...,

            (p+z-y-x)..., c..., (-x)...,
            (p-z+y-x)..., c..., (-x)...,
            (p-z-y-x)..., c..., (-x)...,
            (p+z-y-x)..., c..., (-x)...,
            (p-z+y-x)..., c..., (-x)...,
            (p+z+y-x)..., c..., (-x)...,

            (p+x-z+y)..., c..., y...,
            (p-x+z+y)..., c..., y...,
            (p-x-z+y)..., c..., y...,
            (p+x-z+y)..., c..., y...,
            (p-x+z+y)..., c..., y...,
            (p+x+z+y)..., c..., y...,

            (p+x-z-y)..., c..., (-y)...,
            (p-x+z-y)..., c..., (-y)...,
            (p-x-z-y)..., c..., (-y)...,
            (p+x-z-y)..., c..., (-y)...,
            (p-x+z-y)..., c..., (-y)...,
            (p+x+z-y)..., c..., (-y)...,

            (p+x-y+z)..., c..., z...,
            (p-x+y+z)..., c..., z...,
            (p-x-y+z)..., c..., z...,
            (p+x-y+z)..., c..., z...,
            (p-x+y+z)..., c..., z...,
            (p+x+y+z)..., c..., z...,

            (p+x-y-z)..., c..., (-z)...,
            (p-x+y-z)..., c..., (-z)...,
            (p-x-y-z)..., c..., (-z)...,
            (p+x-y-z)..., c..., (-z)...,
            (p-x+y-z)..., c..., (-z)...,
            (p+x+y-z)..., c..., (-z)...,
        ]
        append!(out, h)
    end
    return out
end

function get_line(v::Vector{Point}, w::Float64, r::Float64)
    out = GLfloat[]
    wv = [w, w*r, 0]
    c = [0.8, 0.8, 0.8]
    prev = to_vec(v[1])
    for i = 2:size(v,1)
        curr = to_vec(v[i])
        n = normalize(cross(curr - prev, [0, 0, 1])) .* wv
        
        d = GLfloat[(prev+n)..., c..., 1, 0, 0,
                    (curr+n)..., c..., 1, 0, 0,
                    (curr-n)..., c..., 1, 0, 0,
                    (prev+n)..., c..., 1, 0, 0,
                    (prev-n)..., c..., 1, 0, 0,
                    (curr-n)..., c..., 1, 0, 0]

        append!(out, d)
        prev = curr
    end
    return out
end

function get_dot(p::Point, w::Float64, r::Float64)
    out = GLfloat[]
    pv = to_vec(p)
    wv = [w, w*r, 0]
    for i = 0:10
        a = i * (π/5.0)
        b = (i+1)  * (π/5.0)
        d = GLfloat[(pv + [cos(a), sin(a), 0] .* wv)..., 1, 1, 1, 1, 0, 0,
                    (pv + [cos(b), sin(b), 0] .* wv)..., 1, 1, 1, 1, 0, 0,
                    (pv)..., 1, 1, 1, 1, 0, 0,]
        append!(out, d)
    end
    return out
end

function update!(s::BSpline)
    p = generate_points(s, 100)
    data = get_geometry(s, p, GLfloat(0.02))
    Buffers.set_data!(s.curve, data)
end

function init(control::Vector{Point}, knots::Vector{Float64})::BSpline
    curve = Buffers.init()

    s = BSpline(control, knots, curve, 0, 0)
    update!(s)

    return s
end

end