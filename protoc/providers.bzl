"""Providers to define protoc plugins."""

ProtocPluginInfo = provider("", fields = {
    "executable": "The plugin executable",
    "default_options": "Options passed to the plugin by default",
    "runfiles": "Made available to the plugin",
    "outputs": """Function to provide names for generated files.

The function signature is 

```
outputs(protos: List[ProtoInfo], outputs_attr: List[str], **kwargs)
```

where `protos` are the ProtoInfo providers of the labels passed to
`protoc_output`s `protos` attribute and args are the output_args passed to
`protoc_output`s `outputs` attribute and **kwargs are the providers 
`outputs_kwargs`.""",
    "outputs_kwargs": "Predefined keyword arguments passed to the output function.",
})
