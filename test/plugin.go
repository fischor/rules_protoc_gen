package main

import (
	"path"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"
)

func main() {
	protogen.Options{}.Run(generate)
}

func generate(gen *protogen.Plugin) error {
	for _, f := range gen.Files {
		if !f.Generate {
			continue
		}
		basename := path.Base(f.GeneratedFilenamePrefix) + ".pb.test"
		dirname := strings.ReplaceAll(*f.Proto.Package, ".", "/")
		filename := path.Join(dirname, basename)
		// The will result in a file with path dirname/basename in the
		// CodeGeneratorResponse.
		g := gen.NewGeneratedFile(filename, f.GoImportPath)
		g.P("hello, world!")
	}
	return nil
}
