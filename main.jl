include("src/buffer.jl")
include("src/shader.jl")
include("src/camera.jl")
include("src/spline.jl")
include("src/window.jl")
include("src/graph.jl")
include("src/grid.jl")

w = init_window()
g = init_grid()

a = Any[g]

render(w, a)