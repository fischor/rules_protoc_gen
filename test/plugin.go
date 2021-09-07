package main

import (
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
		filename := strings.ReplaceAll(*f.Proto.Name, ".proto", ".pb.test")
		// The will result in a file with path dirname/basename in the
		// CodeGeneratorResponse.
		g := gen.NewGeneratedFile(filename, f.GoImportPath)
		g.P("hello, world!")
	}
	return nil
}
