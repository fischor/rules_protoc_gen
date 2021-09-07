"""Rules and functions to define protoc plugins."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//protoc:providers.bzl", "ProtocPluginInfo")

def with_suffix(protos, outputs_attr, **kwargs):
    """Output func."""
    filenames = []
    for proto in protos:
        for file in proto.direct_sources:
            # ProtoInfo.proto_source root is the directory relative to which the
            # .proto files defined in the proto_library are defined. For example, if
            # this is 'a/b' and the rule has the file 'a/b/c/d.proto' as a source,
            # that source file would be imported as 'import c/d.proto'
            # In proto_library rules this can be modified with the "import_prefix""
            # and "strip_import_prefix" and attributes.
            filename = paths.relativize(file.path, proto.proto_source_root)
            filename = filename.replace(".proto", kwargs["suffix"])
            filenames.append(filename)
    return filenames

def with_predeclared_outputs(protos, outputs_attr, **kwargs):
    """Output func."""
    return [output for output in outputs_attr]

def _protoc_plugin_impl(ctx):
    # Fail if there is an illegal attribute combination used.
    if ctx.attr.suffix == "" and ctx.attr.predeclared_outputs == False:
        fail("either \"suffix\" or \"predeclared_outputs\" must be specified")
    if ctx.attr.suffix != "" and ctx.attr.predeclared_outputs == True:
        fail("either \"suffix\" or \"predeclared_outputs\" must be specified, not both")

    if ctx.attr.suffix != "":
        outputs = with_suffix
        outputs_kwargs = {"suffix": ctx.attr.suffix}
    if ctx.attr.predeclared_outputs:
        outputs = with_predeclared_outputs
        outputs_kwargs = {}

    expanded_options = []
    for opt in ctx.attr.default_options:
        # TODO: $(locations ...) produces a space-separated list of output paths,
        # this must somewhat be handeled since it is passed directly to the
        # command line via "key=value value value".
        expanded_options.append(ctx.expand_location(opt, ctx.attr.data))

    # Collect the runfiles necessary to run the plugin.
    runfiles = ctx.runfiles(files = ctx.files.data)
    runfiles = runfiles.merge(ctx.attr.executable[DefaultInfo].default_runfiles)

    return ProtocPluginInfo(
        # executable = wrapper_exec,
        executable = ctx.executable.executable,
        outputs = outputs,
        outputs_kwargs = outputs_kwargs,
        default_options = expanded_options,
        runfiles = runfiles,
    )

protoc_plugin = rule(
    implementation = _protoc_plugin_impl,
    attrs = {
        "executable": attr.label(
            executable = True,
            cfg = "exec",
        ),
        "suffix": attr.string(),
        "predeclared_outputs": attr.bool(),
        "default_options": attr.string_list(),
        "data": attr.label_list(
            doc = "files added to the execution env such that the plugin have access to them",
            allow_files = True,
        ),
    },
)
