set -e

/home/dg/tools/odin_dev/odin build src -out:out/miniaudio-test -o:none -use-separate-modules -vet-style -vet-shadowing -linker:mold -collection:src=src -collection:ext=ext
out/miniaudio-test
