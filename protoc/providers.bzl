"""Providers to define protoc plugins."""

ProtocPluginInfo = provider("A protoc plugin.", fields = {
    "executable": "The plugin executable.",
    "default_options": """Options passed to the plugin whenever it is run.
    
For example: `["x=3", "y=5"]` will be passed as 

```
--<plugin-name>_opt=x=3 --<plugin-name>_opt=y=5
``` 

to the command line line when running protoc with the plugin (`<plugin-name>`).""",
    "runfiles": "Runfiles required by the executable.",
    "outputs": """Function that derives the names of the files the plugin generates from a set of input files.

The function signature is 

```
outputs(protos, outputs_attr, **kwargs)
```

where `protos` is a list of ProtoInfo providers, `output_args` is a list of strings and `**kwargs` are the providers `outputs_kwargs`.

When using `protoc_output` the `protos` are obtain from the `protos` attribute and the `outputs_attr` are obtained from the `outputs` attribute.
""",
    "outputs_kwargs": "Predefined keyword arguments passed to the output function.",
})
