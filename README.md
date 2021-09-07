# `rules_protoc_gen`

A Bazel rule to generate language agnostic code with protoc plugins.

# Installation

```python
git_repository(
    name = "rules_protoc_gen",
    remote = "https://github.com/fischor/rules_protoc_gen",
    commit = "<current-commit>",
)

# You also need bazel_skylib, since rules_proto_gen uses that.

http_archive(
    name = "bazel_skylib",
    sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
    urls = [
        "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
    ],
)

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")

bazel_skylib_workspace()
```

## `@rules_protoc_gen//:def.bzl` 

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Rules to run and generate code with protoc plugins.

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


<a name="#protoc_output"></a>

## protoc_output

<pre>
protoc_output(<a href="#protoc_output-name">name</a>, <a href="#protoc_output-data">data</a>, <a href="#protoc_output-options">options</a>, <a href="#protoc_output-outputs">outputs</a>, <a href="#protoc_output-plugin">plugin</a>, <a href="#protoc_output-plugin_out">plugin_out</a>, <a href="#protoc_output-protoc">protoc</a>, <a href="#protoc_output-protos">protos</a>)
</pre>

Runs a protoc plugin.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| data |  Files added to the actions execution environment such that the plugin can access them.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| options |  Options passed to the plugin. For example: <code>["x=3", "y=5"]</code> will be passed as <br><br><pre><code> --&lt;plugin-name&gt;_opt=x=3 --&lt;plugin-name&gt;_opt=y=5 </code></pre> <br><br>to the command line line when running protoc with the plugin (<code>&lt;plugin-name&gt;</code>). The <code>options</code> are subject to ctx.expanded_locations: For example, use <br><br><pre><code> "config=$(location :my_data_file)" </code></pre><br><br>to obtain the runfile location of <code>:my_data_file</code> and passed it as <code>config</code> option to the plugin. <code>:my_data_file</code> must be passed in the <code>data</code> attribute for the expansion to work. Do not use the <code>locations</code> (note the <code>s</code>) directive.   | List of strings | optional | [] |
| outputs |  Optional output attributes passed to the plugins.<br><br>For plugin that define the their outputs using predeclared outputs, this is the list of predeclared outputs.<br><br>See ProtocPluginInfo.output for more information.   | List of strings | optional | [] |
| plugin |  The plugin to run.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | required |  |
| plugin_out |  The output root to generate the files to. This will be passed as --&lt;plugin-name&gt;_out=&lt;plugin_out&gt; to the protoc executable.<br><br>Defaults to <code>&lt;bazel_package&gt;/&lt;target_name&gt;/</code>. When using a different value, this will affect where to plugin generates its outputs files to. Each file that the plugin returns will be placed under <code>&lt;plugin_out&gt;/&lt;generated_filename&gt;</code>. Bazel requires that all files must be generated under the current Bazel package, so when setting <code>plugin_out</code> set it in a way that the resulting outputs are generated accordingly.   | String | optional | "" |
| protoc |  The protoc executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | @com_google_protobuf//:protoc |
| protos |  The proto libraries to generate code for.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |


<a name="#protoc_plugin"></a>

## protoc_plugin

<pre>
protoc_plugin(<a href="#protoc_plugin-name">name</a>, <a href="#protoc_plugin-data">data</a>, <a href="#protoc_plugin-default_options">default_options</a>, <a href="#protoc_plugin-executable">executable</a>, <a href="#protoc_plugin-predeclared_outputs">predeclared_outputs</a>, <a href="#protoc_plugin-suffix">suffix</a>)
</pre>

Describes a generic protoc plugin.
    
This rule allows to describe and reuse configuration for a protoc plugin that either uses a suffix replacement approach or predeclared outputs to describe the files it generates.
See documentation for `suffix` and `predeclared_outputs` for more information.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :-------------: | :-------------: | :-------------: | :-------------: | :-------------: |
| name |  A unique name for this target.   | <a href="https://bazel.build/docs/build-ref.html#name">Name</a> | required |  |
| data |  Files that should be added to the execution environment whenever the plugin is run.   | <a href="https://bazel.build/docs/build-ref.html#labels">List of labels</a> | optional | [] |
| default_options |  Options that should be passed to the plugin whenever it is run. Note that, if you are using <code>protoc_output</code>, there can also options be passed to the plugin using <code>protoc_output</code>s <code>options</code> attribute on a per target basis.<br><br>For example: <code>["x=3", "y=5"]</code> will be passed as <br><br><pre><code> --&lt;plugin-name&gt;_opt=x=3 --&lt;plugin-name&gt;_opt=y=5 </code></pre> <br><br>to the command line line when running protoc with the plugin (<code>&lt;plugin-name&gt;</code>). The <code>options</code> are subject to ctx.expanded_locations: For example, use <br><br><pre><code> "config=$(location :my_data_file)" </code></pre><br><br>to obtain the runfile location of <code>:my_data_file</code> and passed it as <code>config</code> option to the plugin. <code>:my_data_file</code> must be passed in the <code>data</code> attribute for the expansion to work. Do not use the <code>locations</code> (note the <code>s</code>) directive.   | List of strings | optional | [] |
| executable |  The plugin executable.   | <a href="https://bazel.build/docs/build-ref.html#labels">Label</a> | optional | None |
| predeclared_outputs |  If true, the plugin is configured to accept a list of predeclared outputs when used in a <code>protoc_output</code> target. The list of predeclared outputs is passed in the <code>outputs</code> attribute of the <code>protoc_output</code> rule.   | Boolean | optional | False |
| suffix |  If set, the plugin is expected to generate one file per input file that is named after the input file but replaces the ".proto" suffix with the provided one. Either the <code>suffix</code> attribute or the <code>predeclared_outputs</code> attributes must be set, but not both at the same time.   | String | optional | "" |

## `@rules_protoc_gen//:providers.bzl` 

<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public providers for rules_protoc_gen.
<a name="#ProtocPluginInfo"></a>

## ProtocPluginInfo

<pre>
ProtocPluginInfo(<a href="#ProtocPluginInfo-executable">executable</a>, <a href="#ProtocPluginInfo-default_options">default_options</a>, <a href="#ProtocPluginInfo-runfiles">runfiles</a>, <a href="#ProtocPluginInfo-outputs">outputs</a>, <a href="#ProtocPluginInfo-outputs_kwargs">outputs_kwargs</a>)
</pre>

A protoc plugin.

**FIELDS**


| Name  | Description |
| :-------------: | :-------------: |
| executable |  The plugin executable.    |
| default_options |  Options passed to the plugin whenever it is run.<br><br>For example: <code>["x=3", "y=5"]</code> will be passed as <br><br><pre><code> --&lt;plugin-name&gt;_opt=x=3 --&lt;plugin-name&gt;_opt=y=5 </code></pre> <br><br>to the command line line when running protoc with the plugin (<code>&lt;plugin-name&gt;</code>).    |
| runfiles |  Runfiles required by the executable.    |
| outputs |  Function that derives the names of the files the plugin generates from a set of input files.<br><br>The function signature is <br><br><pre><code> outputs(protos, outputs_attr, **kwargs) </code></pre><br><br>where <code>protos</code> is a list of ProtoInfo providers, <code>output_args</code> is a list of strings and <code>**kwargs</code> are the providers <code>outputs_kwargs</code>.<br><br>When using <code>protoc_output</code> the <code>protos</code> are obtain from the <code>protos</code> attribute and the <code>outputs_attr</code> are obtained from the <code>outputs</code> attribute.    |
| outputs_kwargs |  Predefined keyword arguments passed to the output function.    |
