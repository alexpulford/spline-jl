module Shaders

using ModernGL
import GLAbstraction.glGetProgramiv
import GLAbstraction.glGetActiveUniform
import GLAbstraction.glGetActiveAttrib
using CSyntax

export Shader

mutable struct Shader
    handle::Ref{GLuint}
    uniforms::Dict{Symbol, GLuint}
    attributes::Dict{Symbol, GLuint}
end

function init(vstr::String, fstr::String)::Shader
    vs = Ref(GLuint(0))
    fs = Ref(GLuint(0))
    p = Ref(GLuint(0))

    vs[] = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(vs[], 1, Ptr{GLchar}[pointer(vstr)], C_NULL)
    glCompileShader(vs[])

    fs[] = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(fs[], 1, Ptr{GLchar}[pointer(fstr)], C_NULL)
    glCompileShader(fs[])

    p[] = glCreateProgram()
    glAttachShader(p[], vs[])
    glAttachShader(p[], fs[])
    glLinkProgram(p[])

    uniforms = Dict{Symbol, GLuint}()
    count = glGetProgramiv(p[], GL_ACTIVE_UNIFORMS)-1

    for i = 0:count[]
        name, type, size = glGetActiveUniform(p[], i)
        uniforms[name] = glGetUniformLocation(p[], name)
    end

    attributes = Dict{Symbol, GLuint}()
    count = glGetProgramiv(p[], GL_ACTIVE_ATTRIBUTES)-1

    for i = 0:count[]
        name, type, size = glGetActiveAttrib(p[], i)
        attributes[name] = glGetAttribLocation(p[], name)
    end

    return Shader(p, uniforms, attributes)
end

end