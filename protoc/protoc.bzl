"""Rules to work with protoc plugins in a language agnostic manner.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_proto//proto:defs.bzl", "ProtoInfo")
load("//protoc:providers.bzl", "ProtocPluginInfo")

_DEFAULT_PROTOC = "@com_google_protobuf//:protoc"

def run_protoc(
        ctx,
        protos,
        protoc,
        plugin,
        options,
        outputs,
        plugin_out = ".",
        data = []):
    """Runs protoc with a plugin.

    Args:
        ctx: the Bazel context
        protoc (executable): the protoc program
        protos (list(ProtoInfo)): ProtoInfo provider of the protos to compile
        plugin (executable): the plugin executable
        options (list(str)): list of options passed to the plugin
        plugin_out: out parameter passed to the plugin
        data (depset of File): additional files added to the action as inputs
    """

    # Merge proto root paths of all protos. Each proto root path will be passed
    # with the --proto_path (-I) option to protoc.
    proto_roots = depset(transitive = [p.transitive_proto_path for p in protos])
    args = ctx.actions.args()
    for root in proto_roots.to_list():
        args.add("--proto_path=" + root)

    # actually name does not matter
    name = plugin.basename.replace(".exe", "")
    args.add("--plugin=protoc-gen-" + name + "=" + plugin.path)

    # Add the output prefix. Protoc will put all files that the plugin returns
    # other this folder. E.g. a retuned file `a/b/c.pb.go` will then be placed
    # and thus be generated under `<plugin_out>/a/b/c.pb.go`.
    # The user provided plugin_out is relative to the workspace directory. Join
    # with the Bazel bin directory to generate the output where it is expected
    # by Bazel (bazel-out/{arch}/bin/<plugin_out>).
    plugin_out = paths.join(ctx.bin_dir.path, plugin_out)
    args.add("--" + name + "_out=" + plugin_out)

    # Add option arguments.
    for opt in options:
        args.add("--" + name + "_opt=" + opt)

    # Direct sources that are requested on command line. For these corresponding
    # files will be generated.
    for proto in protos:
        args.add_all(proto.direct_sources)

    # Collect inputs.
    direct_sources = []  # list of File
    for proto in protos:
        direct_sources.extend(proto.direct_sources)
    transitive_sources = [p.transitive_sources for p in protos]  # list of depsets
    inputs = depset(direct_sources, transitive = transitive_sources + [data])  # data is a depset

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = outputs,
        command = "mkdir -p {} && {} $@".format(plugin_out, protoc.path),
        arguments = [args],
        mnemonic = "ProtocPlugins",
        tools = [protoc, plugin],
        progress_message = "Generating plugin output in {}".format(plugin_out),
    )

def _protoc_output_impl(ctx):
    protos = [p[ProtoInfo] for p in ctx.attr.protos]

    # Default the plugin_out parameter to <rule_dir>/<target_name> if not specified.
    plugin_out = ctx.attr.plugin_out
    if plugin_out == "":
        plugin_out = paths.join(ctx.label.package, ctx.label.name)

    # Call the plugin provided output function to obtain the filenames that the plugin
    # is going to generated. See the documentation of ProtocPluginInfo for more information
    # how that works.
    plugin_info = ctx.attr.plugin[ProtocPluginInfo]
    filenames = plugin_info.outputs(protos, ctx.attr.outputs, **plugin_info.outputs_kwargs)

    outputs = []
    for file in filenames:
        out_full_name = paths.join(plugin_out, file)
        if not out_full_name.startswith(ctx.label.package):
            fail("""Trying to generate an output file named \"{}\" that is not under the current package \"{}/\".
Bazel requires files to be generated in/below the package of their corresponging rule.""".format(out_name, ctx.label.package))

        # Make the output path relative to ctx.label.package. When declaring files
        # with ctx.actions.declare_file the file is always assumed to be relative
        # to the current package.
        out_name = paths.relativize(out_full_name, ctx.label.package)
        out = ctx.actions.declare_file(out_name)
        outputs.append(out)

    expanded_options = []
    for opt in ctx.attr.options:
        # TODO: $(locations ...) produces a space-separated list of output paths,
        # this must somewhat be handeled since it is passed directly to the
        # command line via "key=value value value".
        expanded_options.append(ctx.expand_location(opt, ctx.attr.data))

    run_protoc(
        ctx = ctx,
        protos = protos,
        protoc = ctx.executable.protoc,
        plugin = plugin_info.executable,
        outputs = outputs,
        options = expanded_options + plugin_info.default_options,
        plugin_out = plugin_out,
        data = depset(ctx.files.data, transitive = [plugin_info.runfiles.files]),
    )

    return DefaultInfo(files = depset(outputs))

protoc_output = rule(
    implementation = _protoc_output_impl,
    doc = """Runs a protoc plugin.""",
    attrs = {
        "protos": attr.label_list(
            doc = "the proto libraries to compile",
            providers = [ProtoInfo],
            allow_empty = False,
        ),
        "plugin": attr.label(
            doc = "the plugin executable",
            providers = [ProtocPluginInfo],
            mandatory = True,
        ),
        "outputs": attr.string_list(
            doc = "output attributes",
        ),
        "options": attr.string_list(
            doc = """Options passed to the plugins.
For example: `["x=3", "y=5"]` will be passed as 
`--{pluginName}_opt=x=3 --{pluginName}_opt=y=5` to command line.

Subject to ctx.expanded_locations, so use $(location :my_data_file) and
pass that file to data to obtain the path. or execpath, rlocation..?
""",
        ),
        "data": attr.label_list(
            doc = "files added to the execution env such that the plugin have access to them",
            allow_files = True,
        ),
        "plugin_out": attr.string(
            default = "",
            doc = "the --<plugin-name>_out: parameter",
        ),
        "protoc": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label(_DEFAULT_PROTOC),
        ),
    },
)
