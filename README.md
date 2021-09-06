# `rules_protoc_gen`

A Bazel rule to generate language agnostic code with protoc plugins.

## Installation

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