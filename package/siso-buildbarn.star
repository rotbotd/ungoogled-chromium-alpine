# -*- bazel-starlark -*-

load("@builtin//struct.star", "module")

def __platform_properties(ctx):
    container_image = "docker://ungoogled-chromium-alpine-rbe"
    platform = {
        "Architecture": "@RBE_TARGET@",
        "InputRootAbsolutePath": "/home/builder/package/src/chromium-150.0.7871.128",
        "OSFamily": "linux",
        "container-image": container_image,
    }
    return {
        "default": platform,
        "large": platform,
    }

backend = module(
    "backend",
    platform_properties = __platform_properties,
)
