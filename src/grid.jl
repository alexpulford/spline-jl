using ModernGL
using CSyntax
using CSyntax.CStatic
using LinearAlgebra
using Statistics

using .Shaders
using .Splines
using .Buffers

mutable struct Drag
    idx::Int32
    screen_start::Vector{Float32}
    grid_start::Point
end

mutable struct Grid
        shader::Shader
        gizmo::Buffer
        line::Buffer
        graph::Graph
        spline::BSpline
        drag::Drag
end

function init_grid()::Grid

    vsh = """
    #version 150
    uniform mat4 view;
    uniform mat4 proj;
    uniform vec4 offset;
    in vec3 position;
    in vec3 color;
    in vec3 normal;
    out vec3 fColor;
    void main(){
        fColor = (max(dot(normal, vec3(1, 1, 1)), -0.2) * color) + color*0.8;
        gl_Position = proj * view * (vec4(position, 1.0) + offset);
    }
    """
    fsh = """
    #version 150
    in vec3 fColor;
    out vec4 outColor;
    void main() {
        outColor = vec4(fColor, 1.0);
    }
    """

    shader = Shaders.init(vsh, fsh)

    gizmo = Buffers.init()
    Buffers.set_data!(gizmo, generate_gizmo(1, 0.01))

    line = Buffers.init()
    
    drag = Drag(0, Float32[Inf, Inf], Point(0,0,0))

    control = Point[Point(-1, -1, 0), Point(-1, 1, 0,), Point(1, 1, 0), Point(1, -1, 1)]
    knots = Float64[0, 0, 0, 0, 1, 1, 1, 1]
    spline = Splines.init(control, knots)

    graph = init_graph(980, 200)

    return Grid(shader, gizmo, line, graph, spline, drag)
end

const tau = Cfloat(2*π)

function render(g::Grid, display_w, display_h, window_flags)
        ui_x, ui_y = Int64(min(display_w ÷ 3, 300)), Int64(min(display_h ÷ 3, 200))
        ui_w, ui_h = Int64(display_w), Int64(display_h)

        r = (display_h - ui_y)/(display_w - ui_x)

        @cstatic c = Cfloat(tau/40) xr=Cfloat(0.0) yr=Cfloat(0.0) z=Cfloat(10.0) begin
            if(CImGui.IsKeyPressed('A'))
                yr = (yr-c)%tau
            end
            if(CImGui.IsKeyPressed('D'))
                yr = (yr+c)%tau
            end
            if(CImGui.IsKeyPressed('W'))
                xr = (xr-c)%tau
            end
            if(CImGui.IsKeyPressed('S'))
                xr = (xr+c)%tau
            end

            CImGui.SetNextWindowPos((0,0))
            CImGui.SetNextWindowSize((ui_x, ui_h))
            CImGui.Begin("Controls", C_NULL, window_flags)

            if (CImGui.CollapsingHeader("Control Points"))
                idx = 1
                for p in g.spline.control_points
                    tmp = GLfloat[p.x, p.y, p.z]
                    if(CImGui.InputFloat3("P$idx", tmp))
                        g.spline.control_points[idx] = Point(tmp...)
                    end
                    idx += 1
                end
            end

            if (CImGui.CollapsingHeader("Knot Vector"))
                idx = 1
                for k in g.spline.knots
                    tmp = GLfloat(k)
                    @c CImGui.SliderFloat("K$idx", &tmp, 0, 1)
                    g.spline.knots[idx] = Float64(tmp)
                    idx += 1
                end

                @cstatic tmp = Cfloat(0.0) begin
                    CImGui.NewLine()
                    @c CImGui.InputFloat("KN", &tmp)
                    CImGui.SameLine()
                    if(CImGui.Button("Add"))
                        push!(g.spline.knots, tmp)
                        println("added $tmp")
                        tmp = Cfloat(0.0)
                    end
                end
            end

            if (CImGui.CollapsingHeader("Grid Controls"))
                @c CImGui.SliderFloat("x", &xr, -tau, tau)
                @c CImGui.SliderFloat("y", &yr, -tau, tau)
                @c CImGui.SliderFloat("z", &z, 1, 20)
            end

            CImGui.End()

            CImGui.SetNextWindowPos((ui_x, ui_h - ui_y))
            CImGui.SetNextWindowSize((ui_w - ui_x, ui_y))
            CImGui.Begin("Info", C_NULL, window_flags)

            x,y = GLFW.GetCursorPos(w.window)

            if(CImGui.BeginTabBar("Test"))
                if(CImGui.BeginTabItem("Influence"))
                    pos = CImGui.GetCursorScreenPos();
                    ext = CImGui.GetContentRegionAvail();
                    g.graph.mx, g.graph.my =  (x-pos.x)/ext.x, (y-pos.y)/ext.y
                    g.graph.r = ext.x / ext.y
                    @c CImGui.Image(Ptr{Cvoid}(g.graph.fb.tex), CImGui.GetContentRegionAvail(), )
                    CImGui.EndTabItem()
                end
                CImGui.EndTabBar()
            end



            CImGui.End()
            om = ortho(z, r)
            rm = rotation(xr, yr, 0)


            if x > ui_x && y < display_h-ui_y
                x = (2*((x - ui_x)/(display_w - ui_x)) - 1)
                y = -(2*((y)/(display_h - ui_y)) - 1)

                i_o = inv(om)
                i_r = inv(rm)
                p1 = i_r * (i_o * [x, y, -1, 1])
                p2 = i_r * (i_o * [x, y, 1, 1])

                d, p = intersect(p1, p2, rm, om, g.spline.control_points)
                if d < 0.15
                    g.spline.hovered = p
                else
                    g.spline.hovered = 0
                end

                state = GLFW.GetMouseButton(w.window, GLFW.MOUSE_BUTTON_LEFT)
                if(state)
                    if(d < 0.1 && g.drag.idx == 0)
                        g.drag.idx = p
                        g.drag.screen_start = p1
                        g.drag.grid_start = g.spline.control_points[p]
                    end
                    if(g.drag.idx != 0)
                        drag = g.drag.screen_start - p1
                        c_pos = Splines.to_vec(g.drag.grid_start) - drag[1:3]

                        g.spline.control_points[g.drag.idx] = Point(c_pos[1], c_pos[2], c_pos[3])

                        Buffers.set_data!(g.line, GLfloat[p1[1:3]..., 0, 1, 1, 1, 0, 0, p2[1:3]..., 0, 1, 1, 1, 0, 0])
                        
                        g.spline.selected = p
                    end
                else
                    g.drag.idx = 0
                    g.spline.selected = 0
                end
            end

            Splines.update!(g.spline)
            
            glUseProgram(g.shader.handle[])
            glUniformMatrix4fv(g.shader.uniforms[:proj], 1, GL_FALSE, ortho(z, r))
            glUniformMatrix4fv(g.shader.uniforms[:view], 1, GL_FALSE, rotation(xr, yr, 0))
            glUniform4fv(g.shader.uniforms[:offset], 1, GLfloat[0,0,0,0])
        end

        glViewport(ui_x, ui_y, display_w-ui_x, display_h-ui_y)
        glEnable(GL_DEPTH_TEST)
        #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

        Buffers.render(g.gizmo, GL_TRIANGLES)
        Buffers.render(g.line, GL_LINES)
        Buffers.render(g.spline.curve, GL_TRIANGLES)

        glViewport(0, 0, 980, 200)
        glUniformMatrix4fv(g.shader.uniforms[:proj], 1, GL_FALSE, ortho(-0.5, 0.5, -0.5, 0.5, -1, 1))
        glUniformMatrix4fv(g.shader.uniforms[:view], 1, GL_FALSE, identity())
        glUniform4fv(g.shader.uniforms[:offset], 1, GLfloat[-0.5,-0.5,0,0])

        update!(g.graph, g.spline)
        render(g.graph)

        glViewport(0, 0, display_w, display_h)
end

