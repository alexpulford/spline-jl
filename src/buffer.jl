module Buffers

using ModernGL
using CSyntax
using CSyntax.CStatic
using CImGui.OpenGLBackend

export Buffer, Framebuffer, FramebufferAA

mutable struct Buffer
    vao::GLuint
    vbo::GLuint
    count::Int64
end

function init()::Buffer
    vao = GLuint(0)
    @c glGenVertexArrays(1, &vao)
    glBindVertexArray(vao)

    vbo = GLuint(0)
    @c glGenBuffers(1, &vbo)
    glBindBuffer(GL_ARRAY_BUFFER, vbo)

    #Assume Constant Shader
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(GLfloat), Ptr{GLCvoid}(6 * sizeof(GLfloat)));
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(GLfloat), Ptr{GLCvoid}(3 * sizeof(GLfloat)));
    glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 9 * sizeof(GLfloat), C_NULL);

    return Buffer(vao, vbo, 0)
end

function set_data!(b::Buffer, data::Vector{GLfloat})
    b.count = size(data, 1)
    glBindBuffer(GL_ARRAY_BUFFER, b.vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)
end

function render(b::Buffer, mode::Core.Any)
    glBindVertexArray(b.vao)

    #Assume Constant Shader
    glDrawArrays(mode, 0, div(b.count, 6))
end


mutable struct Framebuffer
    fbo::GLuint
    tex
    w::Int64
    h::Int64
end

function init_framebuffer(w::Int64, h::Int64, ms::Bool = false)
    fbo = GLuint(0)
    @c glGenFramebuffers(1, &fbo)
    glBindFramebuffer(GL_FRAMEBUFFER, fbo)

    tex = GLuint(0)
    if(ms)
        @c glGenTextures(1, &tex)
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, tex)
        glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, 4, GL_RGB, w, h, GL_TRUE)
        glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, 0)
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, tex, 0)
    else
        tex = ImGui_ImplOpenGL3_CreateImageTexture(w, h)
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0)
    end
    glBindFramebuffer(GL_FRAMEBUFFER, 0)

    return Framebuffer(fbo, tex, w, h)
end

function unbind()
    glBindFramebuffer(GL_FRAMEBUFFER, 0)
end

function bind(f::Framebuffer)
    glBindFramebuffer(GL_FRAMEBUFFER, f.fbo)
end

function blit(src::Framebuffer, dst::Framebuffer)
    glBindFramebuffer(GL_READ_FRAMEBUFFER, src.fbo);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, dst.fbo);
    glBlitFramebuffer(0, 0, src.w, src.h, 0, 0, src.w, src.h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
end


mutable struct FramebufferAA
    ms::Framebuffer
    tx::Framebuffer
    tex::Int
end

function init_framebufferAA(w::Int64, h::Int64)
    ms = init_framebuffer(w, h, true)
    tx = init_framebuffer(w, h, false)

    return FramebufferAA(ms, tx, tx.tex)
end

function bind(f::FramebufferAA)
    bind(f.ms)
end

function update(f::FramebufferAA)
    blit(f.ms, f.tx)
end

end