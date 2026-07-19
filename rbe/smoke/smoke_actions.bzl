def smoke_actions():
    outputs = []
    for index in range(64):
        output = "remote-action-%02d.txt" % index
        native.genrule(
            name = "remote_action_%02d" % index,
            outs = [output],
            cmd = "sleep 2 && echo remote-execution-ok > $@",
        )
        outputs.append(output)

    native.filegroup(
        name = "all",
        srcs = outputs,
    )
