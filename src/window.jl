using CImGui
using CImGui.LibCImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui.GLFWBackend
using CImGui.OpenGLBackend
using CImGui.GLFWBackend.GLFW
using CImGui.OpenGLBackend.ModernGL
using Printf

mutable struct Window
    window::GLFW.Window
    ctx::Ptr{ImGuiContext}
end

function init_window():: Window
    # init GLFW
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 2)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)

    GLFW.WindowHint(GLFW.SAMPLES, 4);

    # setup GLFW error callback
    error_callback(err::GLFW.GLFWError) = @error "GLFW ERROR: code $(err.code) msg: $(err.description)"
    GLFW.SetErrorCallback(error_callback)

    # create window
    window = GLFW.CreateWindow(1280, 720, "Spline Renderer")
    @assert window != C_NULL
    GLFW.MakeContextCurrent(window)
    
    #GLFWBackend.g_CustomCallbackMousebutton[] = mouse_callback
    GLFW.SwapInterval(1)  # enable vsync

    # init ImGui
    ctx = CImGui.CreateContext()

    CImGui.StyleColorsDark()
    ImGuiStyle_Set_WindowRounding(CImGui.GetStyle(), Cfloat(0))

    fonts_dir = joinpath(@__DIR__, "..", "fonts")
    fonts = CImGui.GetIO().Fonts
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Roboto-Medium.ttf"), 16)

    # setup Platform/Renderer bindings
    ImGui_ImplGlfw_InitForOpenGL(window, true)
    ImGui_ImplOpenGL3_Init(150)

    return Window(window, ctx)
end

function render(w::Window, things::Array{Any, 1})
    try
        clear_color = Cfloat[0.1, 0.1, 0.1, 1.00]
        window_flags = CImGui.ImGuiWindowFlags_NoResize
        window_flags |= CImGui.ImGuiWindowFlags_NoMove
        window_flags |= CImGui.ImGuiWindowFlags_NoCollapse
        window_flags |= CImGui.ImGuiWindowFlags_NoTitleBar

        GLFW.MakeContextCurrent(w.window)
        while !GLFW.WindowShouldClose(w.window)
            GLFW.PollEvents()
            ImGui_ImplOpenGL3_NewFrame()
            ImGui_ImplGlfw_NewFrame()
            CImGui.NewFrame()

            display_w, display_h = GLFW.GetFramebufferSize(w.window)
           
            glViewport(0, 0, display_w, display_h)
            glClearColor(clear_color...)
            glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

            for t in things
                render(t, display_w, display_h, window_flags)
            end

            CImGui.Render()

            ImGui_ImplOpenGL3_RenderDrawData(CImGui.GetDrawData())

            GLFW.MakeContextCurrent(w.window)
            GLFW.SwapBuffers(w.window)
        end
    catch e
        @error "Error in renderloop!" exception=e
        Base.show_backtrace(stderr, catch_backtrace())
    finally
        ImGui_ImplOpenGL3_Shutdown()
        ImGui_ImplGlfw_Shutdown()
        CImGui.DestroyContext(w.ctx)
        GLFW.DestroyWindow(w.window)
    end
end