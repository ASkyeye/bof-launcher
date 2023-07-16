//------------------------------------------------------------------------------
//
// Various types
//
//------------------------------------------------------------------------------
pub const Error = error{
    Unknown,
};

pub const CompletionCallback = *const fn (
    bof_context: *Context,
    user_context: ?*anyopaque,
) callconv(.C) void;
//------------------------------------------------------------------------------
//
// Launcher functions
//
//------------------------------------------------------------------------------
/// Returns zero on success
/// Returns negative value when error occurs
pub fn initLauncher() Error!void {
    if (bofLauncherInit() < 0) return error.Unknown;
}

pub const releaseLauncher = bofLauncherRelease;
//------------------------------------------------------------------------------
//
// Object
//
//------------------------------------------------------------------------------
pub const Object = extern struct {
    handle: u32,

    pub fn initFromMemory(
        file_data_ptr: [*]const u8,
        file_data_len: c_int,
    ) Error!Object {
        var object: Object = undefined;
        if (bofObjectInitFromMemory(
            file_data_ptr,
            file_data_len,
            &object,
        ) < 0) return error.Unknown;
        return object;
    }

    pub const release = bofObjectRelease;

    pub fn isValid(bof_handle: Object) bool {
        return bofObjectIsValid(bof_handle) != 0;
    }

    pub fn run(
        bof_handle: Object,
        arg_data_ptr: ?[*]u8,
        arg_data_len: c_int,
    ) Error!*Context {
        var context: *Context = undefined;
        if (bofObjectRun(
            bof_handle,
            arg_data_ptr,
            arg_data_len,
            &context,
        ) < 0) return error.Unknown;
        return context;
    }

    pub fn runAsync(
        bof_handle: Object,
        arg_data_ptr: ?[*]u8,
        arg_data_len: c_int,
        completion_cb: ?CompletionCallback,
        completion_cb_context: ?*anyopaque,
    ) Error!*Context {
        var context: *Context = undefined;
        if (bofObjectRunAsync(
            bof_handle,
            arg_data_ptr,
            arg_data_len,
            completion_cb,
            completion_cb_context,
            &context,
        ) < 0) return error.Unknown;
        return context;
    }
};
//------------------------------------------------------------------------------
//
// Context
//
//------------------------------------------------------------------------------
pub const Context = opaque {
    pub const release = bofContextRelease;

    pub fn isRunning(context: *Context) bool {
        return bofContextIsRunning(context) != 0;
    }

    pub const wait = bofContextWait;

    pub const getResult = bofContextGetResult;

    pub const getObject = bofContextGetObjectHandle;

    pub fn getOutput(context: *Context) ?[]const u8 {
        var len: c_int = 0;
        const ptr = bofContextGetOutput(context, &len);
        if (ptr == null) return null;
        return ptr.?[0..@intCast(len)];
    }
};
//------------------------------------------------------------------------------
//
// Args
//
//------------------------------------------------------------------------------
pub const Args = opaque {
    pub fn init() Error!*Args {
        var args: *Args = undefined;
        if (bofArgsInit(&args) < 0) return error.Unknown;
        return args;
    }

    pub const release = bofArgsRelease;

    pub const begin = bofArgsBegin;

    pub const end = bofArgsEnd;

    /// Returns zero on success
    /// Returns negative value when error occurs
    pub fn add(args: *Args, arg: [*]const u8, arg_len: c_int) Error!void {
        if (bofArgsAdd(args, arg, arg_len) < 0) return error.Unknown;
    }

    pub const getBuffer = bofArgsGetBuffer;

    pub const getSize = bofArgsGetSize;
};
//------------------------------------------------------------------------------
//
// Raw C functions
//
//------------------------------------------------------------------------------
extern fn bofLauncherInit() callconv(.C) c_int;
extern fn bofLauncherRelease() callconv(.C) void;

extern fn bofObjectInitFromMemory(
    file_data_ptr: [*]const u8,
    file_data_len: c_int,
    out_bof_handle: *Object,
) callconv(.C) c_int;

extern fn bofObjectRelease(bof_handle: Object) callconv(.C) void;

extern fn bofObjectIsValid(bof_handle: Object) callconv(.C) c_int;

extern fn bofObjectRun(
    bof_handle: Object,
    arg_data_ptr: ?[*]u8,
    arg_data_len: c_int,
    out_context: **Context,
) callconv(.C) c_int;

extern fn bofObjectRunAsync(
    bof_handle: Object,
    arg_data_ptr: ?[*]u8,
    arg_data_len: c_int,
    completion_cb: ?CompletionCallback,
    completion_cb_context: ?*anyopaque,
    out_context: **Context,
) callconv(.C) c_int;

extern fn bofContextRelease(context: *Context) callconv(.C) void;
extern fn bofContextIsRunning(context: *Context) callconv(.C) c_int;
extern fn bofContextWait(context: *Context) callconv(.C) void;
extern fn bofContextGetResult(context: *Context) callconv(.C) u8;
extern fn bofContextGetObjectHandle(context: *Context) callconv(.C) Object;
extern fn bofContextGetOutput(context: *Context, out_output_len: ?*c_int) callconv(.C) ?[*:0]const u8;

extern fn bofArgsInit(out_args: **Args) callconv(.C) c_int;
extern fn bofArgsRelease(args: *Args) callconv(.C) void;
extern fn bofArgsAdd(args: *Args, arg: [*]const u8, arg_len: c_int) callconv(.C) c_int;
extern fn bofArgsBegin(args: *Args) callconv(.C) void;
extern fn bofArgsEnd(args: *Args) callconv(.C) void;
extern fn bofArgsGetBuffer(args: *Args) callconv(.C) ?[*]u8;
extern fn bofArgsGetSize(args: *Args) callconv(.C) c_int;
//------------------------------------------------------------------------------
