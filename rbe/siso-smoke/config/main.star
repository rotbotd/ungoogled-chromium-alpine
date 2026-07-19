# -*- bazel-starlark -*-

load("@builtin//encoding.star", "json")
load("@builtin//struct.star", "module")

def init(ctx):
    step_config = {
        "platforms": {
            "default": {
                "OSFamily": "linux",
                "container-image": "docker://ungoogled-chromium-alpine-rbe",
            },
        },
        "rules": [{
            "name": "system-clang/cxx",
            "action": "cxx",
            "command_prefix": "clang++ ",
            "remote": True,
            "timeout": "2m",
            "use_system_input": True,
        }],
    }
    return module(
        "config",
        step_config = json.encode(step_config),
        filegroups = {},
        handlers = {},
    )
