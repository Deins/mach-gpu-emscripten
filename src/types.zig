pub const AlphaMode = enum(u32) {
    premultiplied = 0x00000000,
    unpremultiplied = 0x00000001,
};

pub const BackendType = enum(u32) {
    nul,
    webgpu,
    d3d11,
    d3d12,
    metal,
    vulkan,
    opengl,
    opengles,
};

pub fn backendTypeName(t: BackendType) []const u8 {
    return switch (t) {
        .nul => "Null",
        .webgpu => "WebGPU",
        .d3d11 => "D3D11",
        .d3d12 => "D3D12",
        .metal => "Metal",
        .vulkan => "Vulkan",
        .opengl => "OpenGL",
        .opengles => "OpenGLES",
    };
}

pub const BlendFactor = enum(u32) {
    zero = 0x00000000,
    one = 0x00000001,
    src = 0x00000002,
    one_minus_src = 0x00000003,
    src_alpha = 0x00000004,
    one_minus_src_alpha = 0x00000005,
    dst = 0x00000006,
    one_minus_dst = 0x00000007,
    dst_alpha = 0x00000008,
    one_minus_dst_alpha = 0x00000009,
    src_alpha_saturated = 0x0000000A,
    constant = 0x0000000B,
    one_minus_constant = 0x0000000C,
};

pub const BlendOperation = enum(u32) {
    add = 0x00000000,
    subtract = 0x00000001,
    reverse_subtract = 0x00000002,
    min = 0x00000003,
    max = 0x00000004,
};

pub const CompareFunction = enum(u32) {
    undef = 0x00000000,
    never = 0x00000001,
    less = 0x00000002,
    less_equal = 0x00000003,
    greater = 0x00000004,
    greater_equal = 0x00000005,
    equal = 0x00000006,
    not_equal = 0x00000007,
    always = 0x00000008,
};
