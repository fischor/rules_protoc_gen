"""Rules and functions to define protoc plugins."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("//protoc:providers.bzl", "ProtocPluginInfo")

def with_suffix(protos, outputs_attr, **kwargs):
    """Return output filenames by replacing the .proto suffix.
    
    Args:
        protos (list of ProtoInfo): The ProtoInfo holding the .proto files.
        outputs_attr (list of str): Ignored by `with_suffix`.
        **kwargs: `kwargs["suffix"]` contains the new suffix.
    
    Returns:
        list of str : The output filenames with the new suffix.
    """
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
    """Return a list of predeclared outputs.
    
    Args:
        protos (list of ProtoInfo): Ignored by `with_predeclared_outputs`.
        outputs_attr (list of str): The predeclared outputs.
        **kwargs: `kwargs["suffix"]` Ignored by `with_predeclared_outputs`.
    
    Returns:
        list of str : The predeclared outputs declared in `outputs_attr`.
    """
    return outputs_attr

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
    doc = """Describes a generic protoc plugin.
    
This rule allows to describe and reuse configuration for a protoc plugin that either uses a suffix replacement approach or predeclared outputs to describe the files it generates.
See documentation for `suffix` and `predeclared_outputs` for more information.""",
    attrs = {
        "executable": attr.label(
            executable = True,
            doc = "The plugin executable.",
            cfg = "exec",
        ),
        "suffix": attr.string(
            doc = """If set, the plugin is expected to generate one file per input file that is named after the input file but replaces the \".proto\" suffix with the provided one.
Either the `suffix` attribute or the `predeclared_outputs` attributes must be set, but not both at the same time.""",
        ),
        "predeclared_outputs": attr.bool(
            doc = """If true, the plugin is configured to accept a list of predeclared outputs when used in a `protoc_output` target.
The list of predeclared outputs is passed in the `outputs` attribute of the `protoc_output` rule.
""",
        ),
        "default_options": attr.string_list(
            doc = """Options that should be passed to the plugin whenever it is run.
Note that, if you are using `protoc_output`, there can also options be passed to the plugin using `protoc_output`s `options` attribute on a per target basis.

For example: `["x=3", "y=5"]` will be passed as 

```
--<plugin-name>_opt=x=3 --<plugin-name>_opt=y=5
``` 

to the command line line when running protoc with the plugin (`<plugin-name>`).
The `options` are subject to ctx.expanded_locations: For example, use 

```
"config=$(location :my_data_file)"
```

to obtain the runfile location of `:my_data_file` and passed it as `config` option to the plugin.
`:my_data_file` must be passed in the `data` attribute for the expansion to work.
Do not use the `locations` (note the `s`) directive.""",
        ),
        "data": attr.label_list(
            doc = "Files that should be added to the execution environment whenever the plugin is run.",
            allow_files = True,
        ),
    },
)
