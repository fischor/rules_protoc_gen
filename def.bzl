"""Rules to run and generate code with protoc plugins.

rules_protoc_gen provides two rules to generate output from [`proto_library`](https://docs.bazel.build/versions/main/be/protocol-buffer.html#proto_library) targets with proto plugins:

- [`protoc_plugin`](#protoc_plugin) and
- [`protoc_output`](#protoc_output)

`protoc_plugin` is used to define a plugin.
`protoc_output` is used to generate output using a defined plugin.

Bazel requires to define the set of outputs a target generates before its build action is run.
Different protoc plugins use different strategies of producing outputs.
`rules_protoc_gen` currently supports two ways of producing outputs that should cover every use case: based on a suffix or by letting the rule user manually specify the set of outputs.
However, you also can describe other ways of producing outputs by writing rules that return the `ProtocPluginInfo` provider.

A common way to generate outputs for a protoc plugin is to generate one output file for every proto input file.
For example, a Python plugin might generate one ".py" for each ".proto" file its requested to generate code for.
That way, e.g. for "a/b/c.proto" a file named "a/b/c.py" and for "a/b/d.proto" a file named "a/b/d.py" would be generated. 
To describe this behaviour, use the `protoc_plugin` rule with a `suffix` attribute set to ".py".

Another plugin might produce files based on file options specified in the proto file.
The official Golang plugin bases the names of its outputs files under the `go_package` option.
For example, for a file name `x.proto` that specified a `option go_package = "github.com/fischor/okg` it would generate a file named `github.com/fischor/pkg/x.pb.go`
To describe this behaviour either write your own rule that returns a `ProtoPluginInfo` provider or simply use the `protoc_plugin` rule with the `predeclared_outputs` attribute set to `True` and specify the files that are expected to be generated when the plugin is used with `protoc_output` in `protoc_putputs` `outputs` attribute.

There are endless ways of how a plugin might generate outputs.
As a fallback, a plugin using predeclared outputs always lets the user specify which outputs are generated for each `protoc_output` target.

### Example

```python
load("@rules_protoc_gen//:def.bzl", "protoc_plugin")

protoc_plugin(
    name = "my_plugin",
    executable = ":myexecutable",
    suffix = ".pb.py",
)

# or alternatively

protoc_plugin(
    name = "my_other_plugin",
    executable = ":myexecutable",
    predeclared_outputs = True,
)
```

```python
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_protoc_gen//:def.bzl", "protoc_output")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
    visibility = ["//visibility:public"],
)

protoc_output(
    name = "foo_my_plugin_output",
    plugin = "//path/to:my_plugin"
    protos = [":foo_proto"],
)

protoc_output(
    name = "foo_my_other_plugin_output",
    plugin = "//path/to:my_other_plugin"
    protos = [":foo_proto"],
    outputs = [
        "my/proto/package/foo.py",
    ]
)
```

"""
load("//protoc:protoc.bzl", _protoc_output = "protoc_output")
load("//protoc:plugin.bzl", _protoc_plugin = "protoc_plugin")

protoc_plugin = _protoc_plugin
protoc_output = _protoc_output
