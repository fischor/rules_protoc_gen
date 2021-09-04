"""Rules to work with protoc plugins in a language agnostic manner.
"""

load("@bazel_skylib//lib:paths.bzl", "paths")

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
        data (list(File)): additional files added to the action as inputs
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

    # Add the ouput prefix. Protoc will put all files that the plugin returns
    # other this folder. E.g. a retuned file `a/b/c.pb.go` will then be placed
    # and thus be generated under `<plugin_out>/a/b/c.pb.go`.
    args.add("--" + name + "_out=" + plugin_out)

    # Add option arguments.
    for opt in options:
        args.add("--" + name + "_opt=" + opt)

    # Direct sources that are requested on command line. For these corresponding
    # files will be generated.
    for proto in protos:
        args.add_all(proto.direct_sources)

    # Collect inputs.
    transitive_inputs = [p.transitive_sources for p in protos]
    inputs = depset(data, transitive = transitive_inputs)

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = protoc,
        arguments = [args],
        mnemonic = "ProtocPlugins",
        tools = [plugin],
        progress_message = "Generating plugin output in {}".format(plugin_out),
    )

def _protoc_output_impl(ctx):
    # Fail if there is an illegal attribute combination used.
    if ctx.attr.suffix == "" and len(ctx.attr.predeclared_outputs) == 0:
        fail("either \"suffix\" or \"predeclared_outputs\" must be specified")
    if ctx.attr.suffix != "" and len(ctx.attr.predeclared_outputs) > 0:
        fail("either \"suffix\" or \"predeclared_outputs\" must be specified, not both")
    if len(ctx.attr.predeclared_outputs) > 0 and ctx.attr.plugin_out != "":
        fail("when using predeclared_outputs \"plugin_out\" must not be set. It defaults to the rule directory.")

    outputs = []
    if ctx.attr.suffix:
        for proto in ctx.attr.protos:
            for file in proto[ProtoInfo].direct_sources:
                # When using a suffix, outputs are expected to be generated under
                # the rule directory.
                out_name = file.basename.replace(".proto", ctx.attr.suffix)
                out = ctx.actions.declare_file(out_name)
                outputs.append(out)

        plugin_out = paths.join(ctx.bin_dir.path, ctx.attr.plugin_out)
    if ctx.attr.predeclared_outputs:
        for file in ctx.attr.predeclared_outputs:
            out = ctx.actions.declare_file(file)
            outputs.append(out)

        plugin_out = paths.join(ctx.bin_dir.path, paths.dirname(ctx.build_file_path))

    expanded_options = []
    for opt in ctx.attr.options:
        # TODO: $(locations ...) produces a space-separated list of output paths,
        # this must somewhat be handeled since it is passed directly to the
        # command line via "key=value value value".
        expanded_options.append(ctx.expand_location(opt, ctx.attr.data))

    run_protoc(
        ctx = ctx,
        protoc = ctx.executable.protoc,
        plugin = ctx.executable.plugin,
        outputs = outputs,
        options = expanded_options,
        protos = [p[ProtoInfo] for p in ctx.attr.protos],
        plugin_out = plugin_out,
        data = ctx.files.data,
    )

    return DefaultInfo(files = depset(outputs))

protoc_output = rule(
    implementation = _protoc_output_impl,
    doc = """Runs a protoc plugin.

This rule has two ways of defining its outputs.
Using predeclared_outputs:

```python
protoc_output(
    name = "services_py_output",
    protos = [
        ":service_a_proto", 
        ":service_b_proto", 
        ":service_c_proto"
    ],
    predeclared_outputs = [
        "path/to/my/services_pb.py", 
    ]
    plugin = "//:my_python_plugin",
)
```

The other way is defining a `suffix`. 
It will be used to replace ".proto" for all input files. 
E.g:

```python
protoc_output(
    name = "services_py_output",
    protos = [":services.proto", "other.proto"],
    plugin = "//:my_python_plugin",
    suffix = "_pb.ts",
)
```
""",
    attrs = {
        "protos": attr.label_list(
            doc = "the proto libraries to compile",
            providers = [ProtoInfo],
            allow_empty = False,
        ),
        "plugin": attr.label(
            doc = "the plugin executable",
            cfg = "exec",
            executable = True,
	    mandatory = True,
        ),
        "suffix": attr.string(
            doc = "suffix produced by the plugin",
            mandatory = False,
        ),
        "predeclared_outputs": attr.string_list(
            doc = "list of outputs generated. Either this or suffix must be specified",
            mandatory = False,
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
            default = Label("@com_google_protobuf//:protoc"),
        ),
    },
)
