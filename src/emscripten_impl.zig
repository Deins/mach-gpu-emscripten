const std = @import("std");
const builtin = @import("builtin");
const gpu = @import("main.zig");

pub const c = @cImport({
    // headers come from emscripten sdk path
    @cInclude("webgpu/webgpu.h");
    @cInclude("emscripten/emscripten.h");
    @cInclude("emscripten/html5_webgpu.h");
});

// Emscripten at time of writing doesn't support instance/device creation,
// but it expects that JS will preinitialize the device/instance.
// However for functions that have device argument it expects that 0 will be used.
// Zig bindings doesn't allow zero pointer to be used as *gpu.Instance. 
// So currently to avoid switching instance API to `*allowzero gpu.Instance`
// we just hardcode the instance id in all functions to 0
inline fn getInstance(instance :  *gpu.Instance) c.WGPUInstance {
    // TODO: once createDevice gets implemented, replace with:
    //return instance;
    _ = instance;
    return @intToPtr(c.WGPUInstance, 0);
}

pub const Interface = struct {
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // emscripten implementation specific things
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    pub const is_emscripten = true;

    // custom hook that must be called from js after
    //  Module["preinitializedWebGPUDevice"] has been prepared from html/js side
    var device_ready = false;
    export fn preinitializedWebGPUDeviceReady() void {
        device_ready = true;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // Regular interface
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    pub fn init() void {
        // TODO: review if adapterCreateDevice gets implemented in emscripten
        // or find nicer ways to do this
        var counter: u32 = 0;
        while (!device_ready) {
            if (builtin.mode == .Debug) {
                counter += 1;
                if (counter % 10 == 0) std.log.info("waiting for js to preinitialize webgpu device...", .{});
                if (counter % 200 == 0) {
                    std.log.err(
                        \\waiting for webgpu context takes longer than it should... 
                        \\Have you forgotten to initialize:
                        \\Module['preinitializedWebGPUDevice'] = ...
                        \\ and call 
                        \\Module._preinitializedWebGPUDeviceReady()
                        \\ from JavaScript?!?
                    , .{});
                }
            }
            c.emscripten_sleep(10); // WARN: requires -sASYNCIFY
        }
    }

    pub inline fn createInstance(descriptor: ?*const gpu.Instance.Descriptor) ?*gpu.Instance {
        // TODO: not implemented by emscripten at the moment, once implemented switch to: 
        // return @ptrCast(?*gpu.Instance, c.wgpuCreateInstance(
        //     @ptrCast(?*const c.WGPUInstanceDescriptor, descriptor),
        // ));
        // also see: getInstance()
        _ = descriptor;
        return @intToPtr(*gpu.Instance, 1);
    }

    pub inline fn getProcAddress(device: *gpu.Device, proc_name: [*:0]const u8) ?gpu.Proc {
        return c.wgpuGetProcAddress(
            @ptrCast(c.WGPUDevice, device),
            proc_name,
        );
    }

    var adapter_create_count: i32 = 0;
    pub inline fn adapterCreateDevice(adapter: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor) ?*gpu.Device {
        _ = adapter;
        _ = descriptor;
        // TODO: emscripten doesn't have this fn - we just forward it to emscripten specific get_device()
        // and check that user doesn't attempt to create more than 1 device
        adapter_create_count += 1;
        if (adapter_create_count != 1) {
            std.log.err("wgpu: adapterCreateDevice - no more than one device supported!", .{});
            unreachable;
        }
        return @ptrCast(?*gpu.Device, c.emscripten_webgpu_get_device());
    }

    pub inline fn adapterEnumerateFeatures(adapter: *gpu.Adapter, features: ?[*]gpu.FeatureName) usize {
        return c.wgpuAdapterEnumerateFeatures(
            @ptrCast(c.WGPUAdapter, adapter),
            @ptrCast(?[*]c.WGPUFeatureName, features),
        );
    }

    pub inline fn adapterGetLimits(adapter: *gpu.Adapter, limits: *gpu.SupportedLimits) bool {
        return c.wgpuAdapterGetLimits(
            @ptrCast(c.WGPUAdapter, adapter),
            @ptrCast(*c.WGPUSupportedLimits, limits),
        );
    }

    pub inline fn adapterGetProperties(adapter: *gpu.Adapter, properties: *gpu.Adapter.Properties) void {
        // emscripten asserts that this struct is zero initialized
        // and it just sets few dummy bytes in it, so its kind of useless
        properties.* = std.mem.zeroes(gpu.Adapter.Properties);
        return c.wgpuAdapterGetProperties(
            @ptrCast(c.WGPUAdapter, adapter),
            @ptrCast(*c.WGPUAdapterProperties, properties),
        );
    }

    pub inline fn adapterHasFeature(adapter: *gpu.Adapter, feature: gpu.FeatureName) bool {
        return c.wgpuAdapterHasFeature(
            @ptrCast(c.WGPUAdapter, adapter),
            @enumToInt(feature),
        );
    }

    pub inline fn adapterRequestDevice(adapter: *gpu.Adapter, descriptor: ?*const gpu.Device.Descriptor, callback: gpu.RequestDeviceCallback, userdata: ?*anyopaque) void {
        return c.wgpuAdapterRequestDevice(
            @ptrCast(c.WGPUAdapter, adapter),
            @ptrCast(?*const c.WGPUDeviceDescriptor, descriptor),
            @ptrCast(c.WGPURequestDeviceCallback, callback),
            userdata,
        );
    }

    pub inline fn adapterReference(adapter: *gpu.Adapter) void {
        c.wgpuAdapterReference(@ptrCast(c.WGPUAdapter, adapter));
    }

    pub inline fn adapterRelease(adapter: *gpu.Adapter) void {
        c.wgpuAdapterRelease(@ptrCast(c.WGPUAdapter, adapter));
    }

    pub inline fn bindGroupSetLabel(bind_group: *gpu.BindGroup, label: [*:0]const u8) void {
        c.wgpuAindGroupSetLabel(@ptrCast(c.WGPUBindGroup, bind_group), label);
    }

    pub inline fn bindGroupReference(bind_group: *gpu.BindGroup) void {
        c.wgpuBindGroupReference(@ptrCast(c.WGPUBindGroup, bind_group));
    }

    pub inline fn bindGroupRelease(bind_group: *gpu.BindGroup) void {
        c.wgpuBindGroupRelease(@ptrCast(c.WGPUBindGroup, bind_group));
    }

    pub inline fn bindGroupLayoutSetLabel(bind_group_layout: *gpu.BindGroupLayout, label: [*:0]const u8) void {
        c.wgpuBindGroupLayoutSetLabel(@ptrCast(c.WGPUBindGroupLayout, bind_group_layout), label);
    }

    pub inline fn bindGroupLayoutReference(bind_group_layout: *gpu.BindGroupLayout) void {
        c.wgpuBindGroupLayoutReference(@ptrCast(c.WGPUBindGroupLayout, bind_group_layout));
    }

    pub inline fn bindGroupLayoutRelease(bind_group_layout: *gpu.BindGroupLayout) void {
        c.wgpuBindGroupLayoutRelease(@ptrCast(c.WGPUBindGroupLayout, bind_group_layout));
    }

    pub inline fn bufferDestroy(buffer: *gpu.Buffer) void {
        c.wgpuBufferDestroy(@ptrCast(c.WGPUBuffer, buffer));
    }

    pub inline fn bufferGetConstMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*const anyopaque {
        return c.wgpuBufferGetConstMappedRange(
            @ptrCast(c.WGPUBuffer, buffer),
            offset,
            size,
        );
    }

    pub inline fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: usize) ?*anyopaque {
        return c.wgpuBufferGetMappedRange(
            @ptrCast(c.WGPUBuffer, buffer),
            offset,
            size,
        );
    }

    pub inline fn bufferGetSize(buffer: *gpu.Buffer) u64 {
        return c.wgpuBufferGetSize(@ptrCast(c.WGPUBuffer, buffer));
    }

    pub inline fn bufferGetUsage(buffer: *gpu.Buffer) gpu.Buffer.UsageFlags {
        return @bitCast(gpu.Buffer.UsageFlags, c.wgpuBufferGetUsage(@ptrCast(c.WGPUBuffer, buffer)));
    }

    pub inline fn bufferMapAsync(buffer: *gpu.Buffer, mode: gpu.MapModeFlags, offset: usize, size: usize, callback: gpu.Buffer.MapCallback, userdata: ?*anyopaque) void {
        c.wgpuBufferMapAsync(
            @ptrCast(c.WGPUBuffer, buffer),
            @bitCast(c.WGPUMapModeFlags, mode),
            offset,
            size,
            @ptrCast(c.WGPUBufferMapCallback, callback),
            userdata,
        );
    }

    pub inline fn bufferSetLabel(buffer: *gpu.Buffer, label: [*:0]const u8) void {
        c.wgpuBufferSetLabel(@ptrCast(c.WGPUBuffer, buffer), label);
    }

    pub inline fn bufferUnmap(buffer: *gpu.Buffer) void {
        c.wgpuBufferUnmap(@ptrCast(c.WGPUBuffer, buffer));
    }

    pub inline fn bufferReference(buffer: *gpu.Buffer) void {
        c.wgpuBufferReference(@ptrCast(c.WGPUBuffer, buffer));
    }

    pub inline fn bufferRelease(buffer: *gpu.Buffer) void {
        c.wgpuBufferRelease(@ptrCast(c.WGPUBuffer, buffer));
    }

    pub inline fn commandBufferSetLabel(command_buffer: *gpu.CommandBuffer, label: [*:0]const u8) void {
        c.wgpuCommandBufferSetLabel(@ptrCast(c.WGPUCommandBuffer, command_buffer), label);
    }

    pub inline fn commandBufferReference(command_buffer: *gpu.CommandBuffer) void {
        c.wgpuCommandBufferReference(@ptrCast(c.WGPUCommandBuffer, command_buffer));
    }

    pub inline fn commandBufferRelease(command_buffer: *gpu.CommandBuffer) void {
        c.wgpuCommandBufferRelease(@ptrCast(c.WGPUCommandBuffer, command_buffer));
    }

    pub inline fn commandEncoderBeginComputePass(command_encoder: *gpu.CommandEncoder, descriptor: ?*const gpu.ComputePassDescriptor) *gpu.ComputePassEncoder {
        return @ptrCast(*gpu.ComputePassEncoder, c.wgpuCommandEncoderBeginComputePass(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(?*const c.WGPUComputePassDescriptor, descriptor),
        ));
    }

    pub inline fn commandEncoderBeginRenderPass(command_encoder: *gpu.CommandEncoder, descriptor: *const gpu.RenderPassDescriptor) *gpu.RenderPassEncoder {
        return @ptrCast(*gpu.RenderPassEncoder, c.wgpuCommandEncoderBeginRenderPass(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            // NOTE: change from dawn - removed optional
            @ptrCast(*const c.WGPURenderPassDescriptor, descriptor),
        ));
    }

    pub inline fn commandEncoderClearBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        c.wgpuCommandEncoderClearBuffer(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(c.WGPUBuffer, buffer),
            offset,
            size,
        );
    }

    pub inline fn commandEncoderCopyBufferToBuffer(command_encoder: *gpu.CommandEncoder, source: *gpu.Buffer, source_offset: u64, destination: *gpu.Buffer, destination_offset: u64, size: u64) void {
        c.wgpuCommandEncoderCopyBufferToBuffer(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(c.WGPUBuffer, source),
            source_offset,
            @ptrCast(c.WGPUBuffer, destination),
            destination_offset,
            size,
        );
    }

    pub inline fn commandEncoderCopyBufferToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyBuffer, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        c.wgpuCommandEncoderCopyBufferToTexture(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(*const c.WGPUImageCopyBuffer, source),
            @ptrCast(*const c.WGPUImageCopyTexture, destination),
            @ptrCast(*const c.WGPUExtent3D, copy_size),
        );
    }

    pub inline fn commandEncoderCopyTextureToBuffer(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyBuffer, copy_size: *const gpu.Extent3D) void {
        c.wgpuCommandEncoderCopyTextureToBuffer(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(*const c.WGPUImageCopyTexture, source),
            @ptrCast(*const c.WGPUImageCopyBuffer, destination),
            @ptrCast(*const c.WGPUExtent3D, copy_size),
        );
    }

    pub inline fn commandEncoderCopyTextureToTexture(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        c.wgpuCommandEncoderCopyTextureToTexture(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(*const c.WGPUImageCopyTexture, source),
            @ptrCast(*const c.WGPUImageCopyTexture, destination),
            @ptrCast(*const c.WGPUExtent3D, copy_size),
        );
    }

    pub inline fn commandEncoderCopyTextureToTextureInternal(command_encoder: *gpu.CommandEncoder, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D) void {
        c.wgpuCommandEncoderCopyTextureToTextureInternal(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(*const c.WGPUImageCopyTexture, source),
            @ptrCast(*const c.WGPUImageCopyTexture, destination),
            @ptrCast(*const c.WGPUExtent3D, copy_size),
        );
    }

    pub inline fn commandEncoderFinish(command_encoder: *gpu.CommandEncoder, descriptor: ?*const gpu.CommandBuffer.Descriptor) *gpu.CommandBuffer {
        return @ptrCast(*gpu.CommandBuffer, c.wgpuCommandEncoderFinish(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(?*const c.WGPUCommandBufferDescriptor, descriptor),
        ));
    }

    pub inline fn commandEncoderInjectValidationError(command_encoder: *gpu.CommandEncoder, message: [*:0]const u8) void {
        c.wgpuCommandEncoderInjectValidationError(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            message,
        );
    }

    pub inline fn commandEncoderInsertDebugMarker(command_encoder: *gpu.CommandEncoder, marker_label: [*:0]const u8) void {
        c.wgpuCommandEncoderInsertDebugMarker(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            marker_label,
        );
    }

    pub inline fn commandEncoderPopDebugGroup(command_encoder: *gpu.CommandEncoder) void {
        c.wgpuCommandEncoderPopDebugGroup(@ptrCast(c.WGPUCommandEncoder, command_encoder));
    }

    pub inline fn commandEncoderPushDebugGroup(command_encoder: *gpu.CommandEncoder, group_label: [*:0]const u8) void {
        c.wgpuCommandEncoderPushDebugGroup(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            group_label,
        );
    }

    pub inline fn commandEncoderResolveQuerySet(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, first_query: u32, query_count: u32, destination: *gpu.Buffer, destination_offset: u64) void {
        c.wgpuCommandEncoderResolveQuerySet(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(c.WGPUQuerySet, query_set),
            first_query,
            query_count,
            @ptrCast(c.WGPUBuffer, destination),
            destination_offset,
        );
    }

    pub inline fn commandEncoderSetLabel(command_encoder: *gpu.CommandEncoder, label: [*:0]const u8) void {
        c.wgpuCommandEncoderSetLabel(@ptrCast(c.WGPUCommandEncoder, command_encoder), label);
    }

    pub inline fn commandEncoderWriteBuffer(command_encoder: *gpu.CommandEncoder, buffer: *gpu.Buffer, buffer_offset: u64, data: [*]const u8, size: u64) void {
        c.wgpuCommandEncoderWriteBuffer(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(c.WGPUBuffer, buffer),
            buffer_offset,
            data,
            size,
        );
    }

    pub inline fn commandEncoderWriteTimestamp(command_encoder: *gpu.CommandEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        c.wgpuCommandEncoderWriteTimestamp(
            @ptrCast(c.WGPUCommandEncoder, command_encoder),
            @ptrCast(c.WGPUQuerySet, query_set),
            query_index,
        );
    }

    pub inline fn commandEncoderReference(command_encoder: *gpu.CommandEncoder) void {
        c.wgpuCommandEncoderReference(@ptrCast(c.WGPUCommandEncoder, command_encoder));
    }

    pub inline fn commandEncoderRelease(command_encoder: *gpu.CommandEncoder) void {
        c.wgpuCommandEncoderRelease(@ptrCast(c.WGPUCommandEncoder, command_encoder));
    }

    pub inline fn computePassEncoderDispatchWorkgroups(compute_pass_encoder: *gpu.ComputePassEncoder, workgroup_count_x: u32, workgroup_count_y: u32, workgroup_count_z: u32) void {
        c.wgpuComputePassEncoderDispatchWorkgroups(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            workgroup_count_x,
            workgroup_count_y,
            workgroup_count_z,
        );
    }

    pub inline fn computePassEncoderDispatchWorkgroupsIndirect(compute_pass_encoder: *gpu.ComputePassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        c.wgpuComputePassEncoderDispatchWorkgroupsIndirect(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            @ptrCast(c.WGPUBuffer, indirect_buffer),
            indirect_offset,
        );
    }

    pub inline fn computePassEncoderEnd(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        c.wgpuComputePassEncoderEnd(@ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder));
    }

    pub inline fn computePassEncoderInsertDebugMarker(compute_pass_encoder: *gpu.ComputePassEncoder, marker_label: [*:0]const u8) void {
        c.wgpuComputePassEncoderInsertDebugMarker(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            marker_label,
        );
    }

    pub inline fn computePassEncoderPopDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        c.wgpuComputePassEncoderPopDebugGroup(@ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder));
    }

    pub inline fn computePassEncoderPushDebugGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_label: [*:0]const u8) void {
        c.wgpuComputePassEncoderPushDebugGroup(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            group_label,
        );
    }

    pub inline fn computePassEncoderSetBindGroup(compute_pass_encoder: *gpu.ComputePassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: u32, dynamic_offsets: ?[*]const u32) void {
        c.wgpuComputePassEncoderSetBindGroup(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            group_index,
            @ptrCast(c.WGPUBindGroup, group),
            dynamic_offset_count,
            dynamic_offsets,
        );
    }

    pub inline fn computePassEncoderSetLabel(compute_pass_encoder: *gpu.ComputePassEncoder, label: [*:0]const u8) void {
        c.wgpuComputePassEncoderSetLabel(@ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder), label);
    }

    pub inline fn computePassEncoderSetPipeline(compute_pass_encoder: *gpu.ComputePassEncoder, pipeline: *gpu.ComputePipeline) void {
        c.wgpuComputePassEncoderSetPipeline(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            @ptrCast(c.WGPUComputePipeline, pipeline),
        );
    }

    pub inline fn computePassEncoderWriteTimestamp(compute_pass_encoder: *gpu.ComputePassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        c.wgpuComputePassEncoderWriteTimestamp(
            @ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder),
            @ptrCast(c.WGPUQuerySet, query_set),
            query_index,
        );
    }

    pub inline fn computePassEncoderReference(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        c.wgpuComputePassEncoderReference(@ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder));
    }

    pub inline fn computePassEncoderRelease(compute_pass_encoder: *gpu.ComputePassEncoder) void {
        c.wgpuComputePassEncoderRelease(@ptrCast(c.WGPUComputePassEncoder, compute_pass_encoder));
    }

    pub inline fn computePipelineGetBindGroupLayout(compute_pipeline: *gpu.ComputePipeline, group_index: u32) *gpu.BindGroupLayout {
        return @ptrCast(*gpu.BindGroupLayout, c.wgpuComputePipelineGetBindGroupLayout(
            @ptrCast(c.WGPUComputePipeline, compute_pipeline),
            group_index,
        ));
    }

    pub inline fn computePipelineSetLabel(compute_pipeline: *gpu.ComputePipeline, label: [*:0]const u8) void {
        c.wgpuComputePipelineSetLabel(@ptrCast(c.WGPUComputePipeline, compute_pipeline), label);
    }

    pub inline fn computePipelineReference(compute_pipeline: *gpu.ComputePipeline) void {
        c.wgpuComputePipelineReference(@ptrCast(c.WGPUComputePipeline, compute_pipeline));
    }

    pub inline fn computePipelineRelease(compute_pipeline: *gpu.ComputePipeline) void {
        c.wgpuComputePipelineRelease(@ptrCast(c.WGPUComputePipeline, compute_pipeline));
    }

    pub inline fn deviceCreateBindGroup(device: *gpu.Device, descriptor: *const gpu.BindGroup.Descriptor) *gpu.BindGroup {
        return @ptrCast(*gpu.BindGroup, c.wgpuDeviceCreateBindGroup(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUBindGroupDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateBindGroupLayout(device: *gpu.Device, descriptor: *const gpu.BindGroupLayout.Descriptor) *gpu.BindGroupLayout {
        return @ptrCast(*gpu.BindGroupLayout, c.wgpuDeviceCreateBindGroupLayout(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUBindGroupLayoutDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateBuffer(device: *gpu.Device, descriptor: *const gpu.Buffer.Descriptor) *gpu.Buffer {
        return @ptrCast(*gpu.Buffer, c.wgpuDeviceCreateBuffer(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUBufferDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateCommandEncoder(device: *gpu.Device, descriptor: ?*const gpu.CommandEncoder.Descriptor) *gpu.CommandEncoder {
        return @ptrCast(*gpu.CommandEncoder, c.wgpuDeviceCreateCommandEncoder(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(?*const c.WGPUCommandEncoderDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateComputePipeline(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor) *gpu.ComputePipeline {
        return @ptrCast(*gpu.ComputePipeline, c.wgpuDeviceCreateComputePipeline(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUComputePipelineDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateComputePipelineAsync(device: *gpu.Device, descriptor: *const gpu.ComputePipeline.Descriptor, callback: gpu.CreateComputePipelineAsyncCallback, userdata: ?*anyopaque) void {
        c.wgpuDeviceCreateComputePipelineAsync(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUComputePipelineDescriptor, descriptor),
            @ptrCast(c.WGPUCreateComputePipelineAsyncCallback, callback),
            userdata,
        );
    }

    pub inline fn deviceCreateErrorBuffer(device: *gpu.Device) *gpu.Buffer {
        return @ptrCast(*gpu.Buffer, c.wgpuDeviceCreateErrorBuffer(@ptrCast(c.WGPUDevice, device)));
    }

    pub inline fn deviceCreateErrorExternalTexture(device: *gpu.Device) *gpu.ExternalTexture {
        return @ptrCast(*gpu.ExternalTexture, c.wgpuDeviceCreateErrorExternalTexture(@ptrCast(c.WGPUDevice, device)));
    }

    pub inline fn deviceCreateErrorTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        return @ptrCast(*gpu.Texture, c.wgpuDeviceCreateErrorTexture(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUTextureDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateExternalTexture(device: *gpu.Device, external_texture_descriptor: *const gpu.ExternalTexture.Descriptor) *gpu.ExternalTexture {
        return @ptrCast(*gpu.ExternalTexture, c.wgpuDeviceCreateExternalTexture(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUExternalTextureDescriptor, external_texture_descriptor),
        ));
    }

    pub inline fn deviceCreatePipelineLayout(device: *gpu.Device, pipeline_layout_descriptor: *const gpu.PipelineLayout.Descriptor) *gpu.PipelineLayout {
        return @ptrCast(*gpu.PipelineLayout, c.wgpuDeviceCreatePipelineLayout(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUPipelineLayoutDescriptor, pipeline_layout_descriptor),
        ));
    }

    pub inline fn deviceCreateQuerySet(device: *gpu.Device, descriptor: *const gpu.QuerySet.Descriptor) *gpu.QuerySet {
        return @ptrCast(*gpu.QuerySet, c.wgpuDeviceCreateQuerySet(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUQuerySetDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateRenderBundleEncoder(device: *gpu.Device, descriptor: *const gpu.RenderBundleEncoder.Descriptor) *gpu.RenderBundleEncoder {
        return @ptrCast(*gpu.RenderBundleEncoder, c.wgpuDeviceCreateRenderBundleEncoder(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPURenderBundleEncoderDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateRenderPipeline(device: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor) *gpu.RenderPipeline {
        return @ptrCast(*gpu.RenderPipeline, c.wgpuDeviceCreateRenderPipeline(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPURenderPipelineDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateRenderPipelineAsync(device: *gpu.Device, descriptor: *const gpu.RenderPipeline.Descriptor, callback: gpu.CreateRenderPipelineAsyncCallback, userdata: ?*anyopaque) void {
        c.wgpuDeviceCreateRenderPipelineAsync(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPURenderPipelineDescriptor, descriptor),
            @ptrCast(c.WGPUCreateRenderPipelineAsyncCallback, callback),
            userdata,
        );
    }

    // TODO(self-hosted): this cannot be marked as inline for some reason.
    // https://github.com/ziglang/zig/issues/12545
    pub fn deviceCreateSampler(device: *gpu.Device, descriptor: ?*const gpu.Sampler.Descriptor) *gpu.Sampler {
        return @ptrCast(*gpu.Sampler, c.wgpuDeviceCreateSampler(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(?*const c.WGPUSamplerDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateShaderModule(device: *gpu.Device, descriptor: *const gpu.ShaderModule.Descriptor) *gpu.ShaderModule {
        return @ptrCast(*gpu.ShaderModule, c.wgpuDeviceCreateShaderModule(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUShaderModuleDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateSwapChain(device: *gpu.Device, surface: ?*gpu.Surface, descriptor: *const gpu.SwapChain.Descriptor) *gpu.SwapChain {
        return @ptrCast(*gpu.SwapChain, c.wgpuDeviceCreateSwapChain(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(c.WGPUSurface, surface),
            @ptrCast(*const c.WGPUSwapChainDescriptor, descriptor),
        ));
    }

    pub inline fn deviceCreateTexture(device: *gpu.Device, descriptor: *const gpu.Texture.Descriptor) *gpu.Texture {
        return @ptrCast(*gpu.Texture, c.wgpuDeviceCreateTexture(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*const c.WGPUTextureDescriptor, descriptor),
        ));
    }

    pub inline fn deviceDestroy(device: *gpu.Device) void {
        // TODO: untested
        // currently only one device is supported and it isn't clear if destroying it is supported
        // see: adapterCreateDevice()
        adapter_create_count -= 1;
        c.wgpuDeviceDestroy(@ptrCast(c.WGPUDevice, device));
    }

    pub inline fn deviceEnumerateFeatures(device: *gpu.Device, features: ?[*]gpu.FeatureName) usize {
        return c.wgpuDeviceEnumerateFeatures(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(?[*]c.WGPUFeatureName, features),
        );
    }

    pub inline fn deviceGetLimits(device: *gpu.Device, limits: *gpu.SupportedLimits) bool {
        return c.wgpuDeviceGetLimits(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(*c.WGPUSupportedLimits, limits),
        );
    }

    pub inline fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
        return @ptrCast(*gpu.Queue, c.wgpuDeviceGetQueue(@ptrCast(c.WGPUDevice, device)));
    }

    pub inline fn deviceHasFeature(device: *gpu.Device, feature: gpu.FeatureName) bool {
        return c.wgpuDeviceHasFeature(
            @ptrCast(c.WGPUDevice, device),
            @enumToInt(feature),
        );
    }

    pub inline fn deviceInjectError(device: *gpu.Device, typ: gpu.ErrorType, message: [*:0]const u8) void {
        c.wgpuDeviceInjectError(
            @ptrCast(c.WGPUDevice, device),
            @enumToInt(typ),
            message,
        );
    }

    pub inline fn deviceLoseForTesting(device: *gpu.Device) void {
        c.wgpuDeviceLoseForTesting(@ptrCast(c.WGPUDevice, device));
    }

    pub inline fn devicePopErrorScope(device: *gpu.Device, callback: gpu.ErrorCallback, userdata: ?*anyopaque) bool {
        return c.wgpuDevicePopErrorScope(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(c.WGPUErrorCallback, callback),
            userdata,
        );
    }

    pub inline fn devicePushErrorScope(device: *gpu.Device, filter: gpu.ErrorFilter) void {
        c.wgpuDevicePushErrorScope(
            @ptrCast(c.WGPUDevice, device),
            @enumToInt(filter),
        );
    }

    pub inline fn deviceSetDeviceLostCallback(device: *gpu.Device, callback: ?gpu.Device.LostCallback, userdata: ?*anyopaque) void {
        c.wgpuDeviceSetDeviceLostCallback(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(c.WGPUDeviceLostCallback, callback),
            userdata,
        );
    }

    pub inline fn deviceSetLabel(device: *gpu.Device, label: [*:0]const u8) void {
        c.wgpuDeviceSetLabel(@ptrCast(c.WGPUDevice, device), label);
    }

    pub inline fn deviceSetLoggingCallback(device: *gpu.Device, callback: ?gpu.LoggingCallback, userdata: ?*anyopaque) void {
        c.wgpuDeviceSetLoggingCallback(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(c.WGPULoggingCallback, callback),
            userdata,
        );
    }

    pub inline fn deviceSetUncapturedErrorCallback(device: *gpu.Device, callback: ?gpu.ErrorCallback, userdata: ?*anyopaque) void {
        c.wgpuDeviceSetUncapturedErrorCallback(
            @ptrCast(c.WGPUDevice, device),
            @ptrCast(c.WGPUErrorCallback, callback),
            userdata,
        );
    }

    pub inline fn deviceTick(device: *gpu.Device) void {
        c.wgpuDeviceTick(@ptrCast(c.WGPUDevice, device));
    }

    pub inline fn deviceReference(device: *gpu.Device) void {
        c.wgpuDeviceReference(@ptrCast(c.WGPUDevice, device));
    }

    pub inline fn deviceRelease(device: *gpu.Device) void {
        c.wgpuDeviceRelease(@ptrCast(c.WGPUDevice, device));
    }

    pub inline fn externalTextureDestroy(external_texture: *gpu.ExternalTexture) void {
        c.wgpuExternalTextureDestroy(@ptrCast(c.WGPUExternalTexture, external_texture));
    }

    pub inline fn externalTextureSetLabel(external_texture: *gpu.ExternalTexture, label: [*:0]const u8) void {
        c.wgpuExternalTextureSetLabel(@ptrCast(c.WGPUExternalTexture, external_texture), label);
    }

    pub inline fn externalTextureReference(external_texture: *gpu.ExternalTexture) void {
        c.wgpuExternalTextureReference(@ptrCast(c.WGPUExternalTexture, external_texture));
    }

    pub inline fn externalTextureRelease(external_texture: *gpu.ExternalTexture) void {
        c.wgpuExternalTextureRelease(@ptrCast(c.WGPUExternalTexture, external_texture));
    }

    pub inline fn instanceCreateSurface(instance: *gpu.Instance, descriptor: *const gpu.Surface.Descriptor) *gpu.Surface {
        return @ptrCast(*gpu.Surface, c.wgpuInstanceCreateSurface(
            getInstance(instance),
            @ptrCast(*const c.WGPUSurfaceDescriptor, descriptor),
        ));
    }

    pub inline fn instanceRequestAdapter(instance: *gpu.Instance, options: ?*const gpu.RequestAdapterOptions, callback: gpu.RequestAdapterCallback, userdata: ?*anyopaque) void {
        c.wgpuInstanceRequestAdapter(
            getInstance(instance),
            @ptrCast(?*const c.WGPURequestAdapterOptions, options),
            @ptrCast(c.WGPURequestAdapterCallback, callback),
            userdata,
        );
    }

    pub inline fn instanceReference(instance: *gpu.Instance) void {
        c.wgpuInstanceReference(getInstance(instance));
    }

    pub inline fn instanceRelease(instance: *gpu.Instance) void {
        c.wgpuInstanceRelease(getInstance(instance));
    }

    pub inline fn pipelineLayoutSetLabel(pipeline_layout: *gpu.PipelineLayout, label: [*:0]const u8) void {
        c.wgpuPipelineLayoutSetLabel(@ptrCast(c.WGPUPipelineLayout, pipeline_layout), label);
    }

    pub inline fn pipelineLayoutReference(pipeline_layout: *gpu.PipelineLayout) void {
        c.wgpuPipelineLayoutReference(@ptrCast(c.WGPUPipelineLayout, pipeline_layout));
    }

    pub inline fn pipelineLayoutRelease(pipeline_layout: *gpu.PipelineLayout) void {
        c.wgpuPipelineLayoutRelease(@ptrCast(c.WGPUPipelineLayout, pipeline_layout));
    }

    pub inline fn querySetDestroy(query_set: *gpu.QuerySet) void {
        c.wgpuQuerySetDestroy(@ptrCast(c.WGPUQuerySet, query_set));
    }

    pub inline fn querySetGetCount(query_set: *gpu.QuerySet) u32 {
        return c.wgpuQuerySetGetCount(@ptrCast(c.WGPUQuerySet, query_set));
    }

    pub inline fn querySetGetType(query_set: *gpu.QuerySet) gpu.QueryType {
        return @intToEnum(gpu.QueryType, c.wgpuQuerySetGetType(@ptrCast(c.WGPUQuerySet, query_set)));
    }

    pub inline fn querySetSetLabel(query_set: *gpu.QuerySet, label: [*:0]const u8) void {
        c.wgpuQuerySetSetLabel(@ptrCast(c.WGPUQuerySet, query_set), label);
    }

    pub inline fn querySetReference(query_set: *gpu.QuerySet) void {
        c.wgpuQuerySetReference(@ptrCast(c.WGPUQuerySet, query_set));
    }

    pub inline fn querySetRelease(query_set: *gpu.QuerySet) void {
        c.wgpuQuerySetRelease(@ptrCast(c.WGPUQuerySet, query_set));
    }

    pub inline fn queueCopyTextureForBrowser(queue: *gpu.Queue, source: *const gpu.ImageCopyTexture, destination: *const gpu.ImageCopyTexture, copy_size: *const gpu.Extent3D, options: *const gpu.CopyTextureForBrowserOptions) void {
        c.wgpuQueueCopyTextureForBrowser(
            @ptrCast(c.WGPUQueue, queue),
            @ptrCast(*const c.WGPUImageCopyTexture, source),
            @ptrCast(*const c.WGPUImageCopyTexture, destination),
            @ptrCast(*const c.WGPUExtent3D, copy_size),
            @ptrCast(*const c.WGPUCopyTextureForBrowserOptions, options),
        );
    }

    pub inline fn queueOnSubmittedWorkDone(queue: *gpu.Queue, signal_value: u64, callback: gpu.Queue.WorkDoneCallback, userdata: ?*anyopaque) void {
        c.wgpuQueueOnSubmittedWorkDone(
            @ptrCast(c.WGPUQueue, queue),
            signal_value,
            @ptrCast(c.WGPUQueueWorkDoneCallback, callback),
            userdata,
        );
    }

    pub inline fn queueSetLabel(queue: *gpu.Queue, label: [*:0]const u8) void {
        c.wgpuQueueSetLabel(@ptrCast(c.WGPUQueue, queue), label);
    }

    pub inline fn queueSubmit(queue: *gpu.Queue, command_count: u32, commands: [*]*const gpu.CommandBuffer) void {
        c.wgpuQueueSubmit(
            @ptrCast(c.WGPUQueue, queue),
            command_count,
            @ptrCast([*]const c.WGPUCommandBuffer, commands),
        );
    }

    pub inline fn queueWriteBuffer(queue: *gpu.Queue, buffer: *gpu.Buffer, buffer_offset: u64, data: *const anyopaque, size: usize) void {
        c.wgpuQueueWriteBuffer(
            @ptrCast(c.WGPUQueue, queue),
            @ptrCast(c.WGPUBuffer, buffer),
            buffer_offset,
            data,
            size,
        );
    }

    pub inline fn queueWriteTexture(queue: *gpu.Queue, destination: *const gpu.ImageCopyTexture, data: *const anyopaque, data_size: usize, data_layout: *const gpu.Texture.DataLayout, write_size: *const gpu.Extent3D) void {
        c.wgpuQueueWriteTexture(
            @ptrCast(c.WGPUQueue, queue),
            @ptrCast(*const c.WGPUImageCopyTexture, destination),
            data,
            data_size,
            @ptrCast(*const c.WGPUTextureDataLayout, data_layout),
            @ptrCast(*const c.WGPUExtent3D, write_size),
        );
    }

    pub inline fn queueReference(queue: *gpu.Queue) void {
        c.wgpuQueueReference(@ptrCast(c.WGPUQueue, queue));
    }

    pub inline fn queueRelease(queue: *gpu.Queue) void {
        c.wgpuQueueRelease(@ptrCast(c.WGPUQueue, queue));
    }

    pub inline fn renderBundleReference(render_bundle: *gpu.RenderBundle) void {
        c.wgpuRenderBundleReference(@ptrCast(c.WGPURenderBundle, render_bundle));
    }

    pub inline fn renderBundleRelease(render_bundle: *gpu.RenderBundle) void {
        c.wgpuRenderBundleRelease(@ptrCast(c.WGPURenderBundle, render_bundle));
    }

    pub inline fn renderBundleEncoderDraw(render_bundle_encoder: *gpu.RenderBundleEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        c.wgpuRenderBundleEncoderDraw(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder), vertex_count, instance_count, first_vertex, first_instance);
    }

    pub inline fn renderBundleEncoderDrawIndexed(render_bundle_encoder: *gpu.RenderBundleEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        c.wgpuRenderBundleEncoderDrawIndexed(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            index_count,
            instance_count,
            first_index,
            base_vertex,
            first_instance,
        );
    }

    pub inline fn renderBundleEncoderDrawIndexedIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        c.wgpuRenderBundleEncoderDrawIndexedIndirect(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            @ptrCast(c.WGPUBuffer, indirect_buffer),
            indirect_offset,
        );
    }

    pub inline fn renderBundleEncoderDrawIndirect(render_bundle_encoder: *gpu.RenderBundleEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        c.wgpuRenderBundleEncoderDrawIndirect(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            @ptrCast(c.WGPUBuffer, indirect_buffer),
            indirect_offset,
        );
    }

    pub inline fn renderBundleEncoderFinish(render_bundle_encoder: *gpu.RenderBundleEncoder, descriptor: ?*const gpu.RenderBundle.Descriptor) *gpu.RenderBundle {
        return @ptrCast(*gpu.RenderBundle, c.wgpuRenderBundleEncoderFinish(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            @ptrCast(?*const c.WGPURenderBundleDescriptor, descriptor),
        ));
    }

    pub inline fn renderBundleEncoderInsertDebugMarker(render_bundle_encoder: *gpu.RenderBundleEncoder, marker_label: [*:0]const u8) void {
        c.wgpuRenderBundleEncoderInsertDebugMarker(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            marker_label,
        );
    }

    pub inline fn renderBundleEncoderPopDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        c.wgpuRenderBundleEncoderPopDebugGroup(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder));
    }

    pub inline fn renderBundleEncoderPushDebugGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_label: [*:0]const u8) void {
        c.wgpuRenderBundleEncoderPushDebugGroup(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder), group_label);
    }

    pub inline fn renderBundleEncoderSetBindGroup(render_bundle_encoder: *gpu.RenderBundleEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: u32, dynamic_offsets: ?[*]const u32) void {
        c.wgpuRenderBundleEncoderSetBindGroup(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            group_index,
            @ptrCast(c.WGPUBindGroup, group),
            dynamic_offset_count,
            dynamic_offsets,
        );
    }

    pub inline fn renderBundleEncoderSetIndexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        c.wgpuRenderBundleEncoderSetIndexBuffer(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            @ptrCast(c.WGPUBuffer, buffer),
            @enumToInt(format),
            offset,
            size,
        );
    }

    pub inline fn renderBundleEncoderSetLabel(render_bundle_encoder: *gpu.RenderBundleEncoder, label: [*:0]const u8) void {
        c.wgpuRenderBundleEncoderSetLabel(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder), label);
    }

    pub inline fn renderBundleEncoderSetPipeline(render_bundle_encoder: *gpu.RenderBundleEncoder, pipeline: *gpu.RenderPipeline) void {
        c.wgpuRenderBundleEncoderSetPipeline(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            @ptrCast(c.WGPURenderPipeline, pipeline),
        );
    }

    pub inline fn renderBundleEncoderSetVertexBuffer(render_bundle_encoder: *gpu.RenderBundleEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        c.wgpuRenderBundleEncoderSetVertexBuffer(
            @ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder),
            slot,
            @ptrCast(c.WGPUBuffer, buffer),
            offset,
            size,
        );
    }

    pub inline fn renderBundleEncoderReference(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        c.wgpuRenderBundleEncoderReference(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder));
    }

    pub inline fn renderBundleEncoderRelease(render_bundle_encoder: *gpu.RenderBundleEncoder) void {
        c.wgpuRenderBundleEncoderRelease(@ptrCast(c.WGPURenderBundleEncoder, render_bundle_encoder));
    }

    pub inline fn renderPassEncoderBeginOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder, query_index: u32) void {
        c.wgpuRenderPassEncoderBeginOcclusionQuery(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            query_index,
        );
    }

    pub inline fn renderPassEncoderDraw(render_pass_encoder: *gpu.RenderPassEncoder, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        c.wgpuRenderPassEncoderDraw(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            vertex_count,
            instance_count,
            first_vertex,
            first_instance,
        );
    }

    pub inline fn renderPassEncoderDrawIndexed(render_pass_encoder: *gpu.RenderPassEncoder, index_count: u32, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32) void {
        c.wgpuRenderPassEncoderDrawIndexed(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            index_count,
            instance_count,
            first_index,
            base_vertex,
            first_instance,
        );
    }

    pub inline fn renderPassEncoderDrawIndexedIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        c.wgpuRenderPassEncoderDrawIndexedIndirect(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(c.WGPUBuffer, indirect_buffer),
            indirect_offset,
        );
    }

    pub inline fn renderPassEncoderDrawIndirect(render_pass_encoder: *gpu.RenderPassEncoder, indirect_buffer: *gpu.Buffer, indirect_offset: u64) void {
        c.wgpuRenderPassEncoderDrawIndirect(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(c.WGPUBuffer, indirect_buffer),
            indirect_offset,
        );
    }

    pub inline fn renderPassEncoderEnd(render_pass_encoder: *gpu.RenderPassEncoder) void {
        // NOTE: rename wgpuRenderPassEncoderEndPass -> wgpuRenderPassEncoderEnd
        c.wgpuRenderPassEncoderEnd(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder));
    }

    pub inline fn renderPassEncoderEndOcclusionQuery(render_pass_encoder: *gpu.RenderPassEncoder) void {
        c.wgpuRenderPassEncoderEndOcclusionQuery(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder));
    }

    pub inline fn renderPassEncoderExecuteBundles(render_pass_encoder: *gpu.RenderPassEncoder, bundles_count: u32, bundles: [*]const *const gpu.RenderBundle) void {
        c.wgpuRenderPassEncoderExecuteBundles(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            bundles_count,
            @ptrCast([*]const c.WGPURenderBundle, bundles),
        );
    }

    pub inline fn renderPassEncoderInsertDebugMarker(render_pass_encoder: *gpu.RenderPassEncoder, marker_label: [*:0]const u8) void {
        c.wgpuRenderPassEncoderInsertDebugMarker(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder), marker_label);
    }

    pub inline fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder) void {
        c.wgpuRenderPassEncoderPopDebugGroup(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder));
    }

    pub inline fn renderPassEncoderPushDebugGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_label: [*:0]const u8) void {
        c.wgpuRenderPassEncoderPushDebugGroup(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            group_label,
        );
    }

    pub inline fn renderPassEncoderSetBindGroup(render_pass_encoder: *gpu.RenderPassEncoder, group_index: u32, group: *gpu.BindGroup, dynamic_offset_count: u32, dynamic_offsets: ?[*]const u32) void {
        c.wgpuRenderPassEncoderSetBindGroup(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            group_index,
            @ptrCast(c.WGPUBindGroup, group),
            dynamic_offset_count,
            dynamic_offsets,
        );
    }

    pub inline fn renderPassEncoderSetBlendConstant(render_pass_encoder: *gpu.RenderPassEncoder, color: *const gpu.Color) void {
        c.wgpuRenderPassEncoderSetBlendConstant(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(*const c.WGPUColor, color),
        );
    }

    pub inline fn renderPassEncoderSetIndexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, buffer: *gpu.Buffer, format: gpu.IndexFormat, offset: u64, size: u64) void {
        c.wgpuRenderPassEncoderSetIndexBuffer(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(c.WGPUBuffer, buffer),
            @enumToInt(format),
            offset,
            size,
        );
    }

    pub inline fn renderPassEncoderSetLabel(render_pass_encoder: *gpu.RenderPassEncoder, label: [*:0]const u8) void {
        c.wgpuRenderPassEncoderSetLabel(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder), label);
    }

    pub inline fn renderPassEncoderSetPipeline(render_pass_encoder: *gpu.RenderPassEncoder, pipeline: *gpu.RenderPipeline) void {
        c.wgpuRenderPassEncoderSetPipeline(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(c.WGPURenderPipeline, pipeline),
        );
    }

    pub inline fn renderPassEncoderSetScissorRect(render_pass_encoder: *gpu.RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) void {
        c.wgpuRenderPassEncoderSetScissorRect(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            x,
            y,
            width,
            height,
        );
    }

    pub inline fn renderPassEncoderSetStencilReference(render_pass_encoder: *gpu.RenderPassEncoder, reference: u32) void {
        c.wgpuRenderPassEncoderSetStencilReference(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            reference,
        );
    }

    pub inline fn renderPassEncoderSetVertexBuffer(render_pass_encoder: *gpu.RenderPassEncoder, slot: u32, buffer: *gpu.Buffer, offset: u64, size: u64) void {
        c.wgpuRenderPassEncoderSetVertexBuffer(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            slot,
            @ptrCast(c.WGPUBuffer, buffer),
            offset,
            size,
        );
    }

    pub inline fn renderPassEncoderSetViewport(render_pass_encoder: *gpu.RenderPassEncoder, x: f32, y: f32, width: f32, height: f32, min_depth: f32, max_depth: f32) void {
        c.wgpuRenderPassEncoderSetViewport(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            x,
            y,
            width,
            height,
            min_depth,
            max_depth,
        );
    }

    pub inline fn renderPassEncoderWriteTimestamp(render_pass_encoder: *gpu.RenderPassEncoder, query_set: *gpu.QuerySet, query_index: u32) void {
        c.wgpuRenderPassEncoderWriteTimestamp(
            @ptrCast(c.WGPURenderPassEncoder, render_pass_encoder),
            @ptrCast(c.WGPUQuerySet, query_set),
            query_index,
        );
    }

    pub inline fn renderPassEncoderReference(render_pass_encoder: *gpu.RenderPassEncoder) void {
        c.wgpuRenderPassEncoderReference(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder));
    }

    pub inline fn renderPassEncoderRelease(render_pass_encoder: *gpu.RenderPassEncoder) void {
        c.wgpuRenderPassEncoderRelease(@ptrCast(c.WGPURenderPassEncoder, render_pass_encoder));
    }

    pub inline fn renderPipelineGetBindGroupLayout(render_pipeline: *gpu.RenderPipeline, group_index: u32) *gpu.BindGroupLayout {
        return @ptrCast(*gpu.BindGroupLayout, c.wgpuRenderPipelineGetBindGroupLayout(
            @ptrCast(c.WGPURenderPipeline, render_pipeline),
            group_index,
        ));
    }

    pub inline fn renderPipelineSetLabel(render_pipeline: *gpu.RenderPipeline, label: [*:0]const u8) void {
        c.wgpuRenderPipelineSetLabel(@ptrCast(c.WGPURenderPipeline, render_pipeline), label);
    }

    pub inline fn renderPipelineReference(render_pipeline: *gpu.RenderPipeline) void {
        c.wgpuRenderPipelineReference(@ptrCast(c.WGPURenderPipeline, render_pipeline));
    }

    pub inline fn renderPipelineRelease(render_pipeline: *gpu.RenderPipeline) void {
        c.wgpuRenderPipelineRelease(@ptrCast(c.WGPURenderPipeline, render_pipeline));
    }

    pub inline fn samplerSetLabel(sampler: *gpu.Sampler, label: [*:0]const u8) void {
        c.wgpuSamplerSetLabel(@ptrCast(c.WGPUSampler, sampler), label);
    }

    pub inline fn samplerReference(sampler: *gpu.Sampler) void {
        c.wgpuSamplerReference(@ptrCast(c.WGPUSampler, sampler));
    }

    pub inline fn samplerRelease(sampler: *gpu.Sampler) void {
        c.wgpuSamplerRelease(@ptrCast(c.WGPUSampler, sampler));
    }

    pub inline fn shaderModuleGetCompilationInfo(shader_module: *gpu.ShaderModule, callback: gpu.CompilationInfoCallback, userdata: ?*anyopaque) void {
        c.wgpuShaderModuleGetCompilationInfo(
            @ptrCast(c.WGPUShaderModule, shader_module),
            @ptrCast(c.WGPUCompilationInfoCallback, callback),
            userdata,
        );
    }

    pub inline fn shaderModuleSetLabel(shader_module: *gpu.ShaderModule, label: [*:0]const u8) void {
        c.wgpuShaderModuleSetLabel(@ptrCast(c.WGPUShaderModule, shader_module), label);
    }

    pub inline fn shaderModuleReference(shader_module: *gpu.ShaderModule) void {
        c.wgpuShaderModuleReference(@ptrCast(c.WGPUShaderModule, shader_module));
    }

    pub inline fn shaderModuleRelease(shader_module: *gpu.ShaderModule) void {
        c.wgpuShaderModuleRelease(@ptrCast(c.WGPUShaderModule, shader_module));
    }

    pub inline fn surfaceReference(surface: *gpu.Surface) void {
        c.wgpuSurfaceReference(@ptrCast(c.WGPUSurface, surface));
    }

    pub inline fn surfaceRelease(surface: *gpu.Surface) void {
        c.wgpuSurfaceRelease(@ptrCast(c.WGPUSurface, surface));
    }

    pub inline fn swapChainConfigure(swap_chain: *gpu.SwapChain, format: gpu.Texture.Format, allowed_usage: gpu.Texture.UsageFlags, width: u32, height: u32) void {
        c.wgpuSwapChainConfigure(
            @ptrCast(c.WGPUSwapChain, swap_chain),
            @enumToInt(format),
            @bitCast(c.WGPUTextureUsageFlags, allowed_usage),
            width,
            height,
        );
    }

    pub inline fn swapChainGetCurrentTextureView(swap_chain: *gpu.SwapChain) *gpu.TextureView {
        return @ptrCast(*gpu.TextureView, c.wgpuSwapChainGetCurrentTextureView(@ptrCast(c.WGPUSwapChain, swap_chain)));
    }

    pub inline fn swapChainPresent(swap_chain: *gpu.SwapChain) void {
        // fails at runtime: Aborted(wgpuSwapChainPresent is unsupported (use requestAnimationFrame via html5.h instead))
        c.wgpuSwapChainPresent(@ptrCast(c.WGPUSwapChain, swap_chain));
    }

    pub inline fn swapChainReference(swap_chain: *gpu.SwapChain) void {
        c.wgpuSwapChainReference(@ptrCast(c.WGPUSwapChain, swap_chain));
    }

    pub inline fn swapChainRelease(swap_chain: *gpu.SwapChain) void {
        c.wgpuSwapChainRelease(@ptrCast(c.WGPUSwapChain, swap_chain));
    }

    pub inline fn textureCreateView(texture: *gpu.Texture, descriptor: ?*const gpu.TextureView.Descriptor) *gpu.TextureView {
        return @ptrCast(*gpu.TextureView, c.wgpuTextureCreateView(
            @ptrCast(c.WGPUTexture, texture),
            @ptrCast(?*const c.WGPUTextureViewDescriptor, descriptor),
        ));
    }

    pub inline fn textureDestroy(texture: *gpu.Texture) void {
        c.wgpuTextureDestroy(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureGetDepthOrArrayLayers(texture: *gpu.Texture) u32 {
        return c.wgpuTextureGetDepthOrArrayLayers(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureGetDimension(texture: *gpu.Texture) gpu.Texture.Dimension {
        return @intToEnum(gpu.Texture.Dimension, c.wgpuTextureGetDimension(@ptrCast(c.WGPUTexture, texture)));
    }

    pub inline fn textureGetFormat(texture: *gpu.Texture) gpu.Texture.Format {
        return @intToEnum(gpu.Texture.Format, c.wgpuTextureGetFormat(@ptrCast(c.WGPUTexture, texture)));
    }

    pub inline fn textureGetHeight(texture: *gpu.Texture) u32 {
        return c.wgpuTextureGetHeight(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureGetMipLevelCount(texture: *gpu.Texture) u32 {
        return c.wgpuTextureGetMipLevelCount(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureGetSampleCount(texture: *gpu.Texture) u32 {
        return c.wgpuTextureGetSampleCount(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureGetUsage(texture: *gpu.Texture) gpu.Texture.UsageFlags {
        return @bitCast(gpu.Texture.UsageFlags, c.wgpuTextureGetUsage(
            @ptrCast(c.WGPUTexture, texture),
        ));
    }

    pub inline fn textureGetWidth(texture: *gpu.Texture) u32 {
        return c.wgpuTextureGetWidth(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureSetLabel(texture: *gpu.Texture, label: [*:0]const u8) void {
        c.wgpuTextureSetLabel(@ptrCast(c.WGPUTexture, texture), label);
    }

    pub inline fn textureReference(texture: *gpu.Texture) void {
        c.wgpuTextureReference(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureRelease(texture: *gpu.Texture) void {
        c.wgpuTextureRelease(@ptrCast(c.WGPUTexture, texture));
    }

    pub inline fn textureViewSetLabel(texture_view: *gpu.TextureView, label: [*:0]const u8) void {
        c.wgpuTextureViewSetLabel(@ptrCast(c.WGPUTextureView, texture_view), label);
    }

    pub inline fn textureViewReference(texture_view: *gpu.TextureView) void {
        c.wgpuTextureViewReference(@ptrCast(c.WGPUTextureView, texture_view));
    }

    pub inline fn textureViewRelease(texture_view: *gpu.TextureView) void {
        c.wgpuTextureViewRelease(@ptrCast(c.WGPUTextureView, texture_view));
    }
};

/////////////////////////////////////////////////////////////////////////////////////////////////////
// Binding validations, tests and utils
/////////////////////////////////////////////////////////////////////////////////////////////////////
fn assertStructBindings(a: anytype, b: anytype) void {
    comptime if (@sizeOf(a) != @sizeOf(b)) {
        @compileLog("emscripten webgpu.h <-> mach_gpu struct size mismatch! Types: ", @TypeOf(a), @TypeOf(b));
        unreachable;
    };
    // more checks? iterate struct fields?
    // emscripten in .Debug mode asserts at runtime if required field is missing etc. but something might slip through
}

comptime {
    assertStructBindings(gpu.ChainedStruct, c.WGPUChainedStruct);
    assertStructBindings(gpu.ChainedStructOut, c.WGPUChainedStructOut);
    assertStructBindings(gpu.Adapter.Properties, c.WGPUAdapterProperties);
    assertStructBindings(gpu.BindGroup.Entry, c.WGPUBindGroupEntry);
    assertStructBindings(gpu.BlendComponent, c.WGPUBlendComponent);
    assertStructBindings(gpu.Buffer.BindingLayout, c.WGPUBufferBindingLayout);
    assertStructBindings(gpu.Buffer.Descriptor, c.WGPUBufferDescriptor);
    assertStructBindings(gpu.Color, c.WGPUColor);
    assertStructBindings(gpu.CommandBuffer.Descriptor, c.WGPUCommandBufferDescriptor);
    assertStructBindings(gpu.CommandEncoder.Descriptor, c.WGPUCommandEncoderDescriptor);
    assertStructBindings(gpu.CompilationMessage, c.WGPUCompilationMessage);
    assertStructBindings(gpu.ComputePassTimestampWrite, c.WGPUComputePassTimestampWrite);
    assertStructBindings(gpu.ConstantEntry, c.WGPUConstantEntry);
    assertStructBindings(gpu.Extent3D, c.WGPUExtent3D);
    assertStructBindings(gpu.Instance.Descriptor, c.WGPUInstanceDescriptor);
    assertStructBindings(gpu.Limits, c.WGPULimits);
    assertStructBindings(gpu.MultisampleState, c.WGPUMultisampleState);
    assertStructBindings(gpu.Origin3D, c.WGPUOrigin3D);
    assertStructBindings(gpu.PipelineLayout.Descriptor, c.WGPUPipelineLayoutDescriptor);
    assertStructBindings(gpu.PrimitiveDepthClipControl, c.WGPUPrimitiveDepthClipControl);
    assertStructBindings(gpu.PrimitiveState, c.WGPUPrimitiveState);
    assertStructBindings(gpu.QuerySet.Descriptor, c.WGPUQuerySetDescriptor);
    assertStructBindings(gpu.Queue.Descriptor, c.WGPUQueueDescriptor);
    assertStructBindings(gpu.RenderBundle.Descriptor, c.WGPURenderBundleDescriptor);
    assertStructBindings(gpu.RenderBundleEncoder.Descriptor, c.WGPURenderBundleEncoderDescriptor);
    assertStructBindings(gpu.RenderPassDepthStencilAttachment, c.WGPURenderPassDepthStencilAttachment);
    assertStructBindings(gpu.RenderPassDescriptorMaxDrawCount, c.WGPURenderPassDescriptorMaxDrawCount);
    assertStructBindings(gpu.RenderPassTimestampWrite, c.WGPURenderPassTimestampWrite);
    assertStructBindings(gpu.RequestAdapterOptions, c.WGPURequestAdapterOptions);
    assertStructBindings(gpu.Sampler.BindingLayout, c.WGPUSamplerBindingLayout);
    assertStructBindings(gpu.Sampler.Descriptor, c.WGPUSamplerDescriptor);
    assertStructBindings(gpu.ShaderModule.Descriptor, c.WGPUShaderModuleDescriptor);
    assertStructBindings(gpu.ShaderModule.SPIRVDescriptor, c.WGPUShaderModuleSPIRVDescriptor);
    assertStructBindings(gpu.ShaderModule.WGSLDescriptor, c.WGPUShaderModuleWGSLDescriptor);
    assertStructBindings(gpu.StencilFaceState, c.WGPUStencilFaceState);
    assertStructBindings(gpu.StorageTextureBindingLayout, c.WGPUStorageTextureBindingLayout);
    assertStructBindings(gpu.Surface.Descriptor, c.WGPUSurfaceDescriptor);
    assertStructBindings(gpu.Surface.DescriptorFromCanvasHTMLSelector, c.WGPUSurfaceDescriptorFromCanvasHTMLSelector);
    // zig struct has extra field a end - should not break anything
    //assertStructBindings(gpu.SwapChain.Descriptor, c.WGPUSwapChainDescriptor);
    assertStructBindings(gpu.Texture.BindingLayout, c.WGPUTextureBindingLayout);
    assertStructBindings(gpu.Texture.DataLayout, c.WGPUTextureDataLayout);
    assertStructBindings(gpu.TextureView.Descriptor, c.WGPUTextureViewDescriptor);
    assertStructBindings(gpu.VertexAttribute, c.WGPUVertexAttribute);
    assertStructBindings(gpu.BindGroup.Descriptor, c.WGPUBindGroupDescriptor);
    assertStructBindings(gpu.BindGroupLayout.Entry, c.WGPUBindGroupLayoutEntry);
    assertStructBindings(gpu.BlendState, c.WGPUBlendState);
    assertStructBindings(gpu.CompilationInfo, c.WGPUCompilationInfo);
    assertStructBindings(gpu.ComputePassDescriptor, c.WGPUComputePassDescriptor);
    assertStructBindings(gpu.DepthStencilState, c.WGPUDepthStencilState);
    assertStructBindings(gpu.ImageCopyBuffer, c.WGPUImageCopyBuffer);
    assertStructBindings(gpu.ImageCopyTexture, c.WGPUImageCopyTexture);
    assertStructBindings(gpu.ProgrammableStageDescriptor, c.WGPUProgrammableStageDescriptor);
    assertStructBindings(gpu.RenderPassColorAttachment, c.WGPURenderPassColorAttachment);
    assertStructBindings(gpu.RequiredLimits, c.WGPURequiredLimits);
    assertStructBindings(gpu.SupportedLimits, c.WGPUSupportedLimits);
    assertStructBindings(gpu.Texture.Descriptor, c.WGPUTextureDescriptor);
    assertStructBindings(gpu.VertexBufferLayout, c.WGPUVertexBufferLayout);
    assertStructBindings(gpu.BindGroupLayout.Descriptor, c.WGPUBindGroupLayoutDescriptor);
    assertStructBindings(gpu.ColorTargetState, c.WGPUColorTargetState);
    assertStructBindings(gpu.ComputePipeline.Descriptor, c.WGPUComputePipelineDescriptor);
    assertStructBindings(gpu.Device.Descriptor, c.WGPUDeviceDescriptor);
    assertStructBindings(gpu.RenderPassDescriptor, c.WGPURenderPassDescriptor);
    assertStructBindings(gpu.VertexState, c.WGPUVertexState);
    assertStructBindings(gpu.FragmentState, c.WGPUFragmentState);
    assertStructBindings(gpu.RenderPipeline.Descriptor, c.WGPURenderPipelineDescriptor);
}
