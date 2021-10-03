using ModernGL
using CSyntax
using CSyntax.CStatic
using LinearAlgebra
using Statistics

using .Splines
using .Buffers

mutable struct Graph
    fb::FramebufferAA
    mx::Float64
    my::Float64

    r::Float64

    lines::Vector{Vector{Point}}
    buffer::Buffer
end

function init_graph(w::Int64, h::Int64)
    lines =  Vector{Vector{Point}}(undef, 0)
    return Graph(Buffers.init_framebufferAA(w, h), -1.0, -1.0, 1.0, lines, Buffers.init())
end

function update!(g::Graph, s::BSpline)
    count = size(s.control_points, 1)

    g.lines = Vector{Vector{Point}}(undef, count)
    for i = 1:count
        v = Splines.get_influence(s, i, 100)
        g.lines[i] = v
    end

    out = GLfloat[]
    i = clamp(floor(Int, g.mx * 100), 1, 101)
    for l in g.lines
        append!(out, Splines.get_line(l, 0.002, g.r))
        append!(out, Splines.get_dot(l[i], 0.004, g.r))
    end
    Buffers.set_data!(g.buffer, out)
end

function render(g::Graph)
    Buffers.bind(g.fb)
    glClear(GL_COLOR_BUFFER_BIT)
    glLineWidth(2)
    Buffers.render(g.buffer, GL_TRIANGLES)
    Buffers.unbind()
    Buffers.update(g.fb)
end
