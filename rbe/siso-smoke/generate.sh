#!/bin/sh
set -eu

cat > build.ninja <<'EOF'
rule cxx
  command = /usr/lib/llvm22/bin/clang++ -O2 -c $in -o $out
  description = CXX $out
EOF

outputs=
for index in $(seq 1 64); do
	output="obj/hello-$index.o"
	printf 'build %s: cxx hello.cc\n' "$output" >> build.ninja
	outputs="$outputs $output"
done
printf 'build all: phony%s\ndefault all\n' "$outputs" >> build.ninja
