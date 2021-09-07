package main

import (
	"fmt"
	"io/ioutil"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/protobuf/compiler/protogen"
)

var (
	configPath = "test/protoc_plugin/executable_runfiles.conf"
)

func main() {
	protogen.Options{}.Run(func(gen *protogen.Plugin) error {
		conf, err := bazel.Runfile(configPath)
		if err != nil {
			panic(err)
		}

		config, err := ioutil.ReadFile(conf)
		if err != nil {
			panic(fmt.Sprintf("failed to open %q: %v", conf, err))
		}
		greeting := strings.TrimSpace(string(config))
		for _, f := range gen.Files {
			if f.Generate {
				filename := strings.ReplaceAll(*f.Proto.Name, ".proto", ".executable_runfiles.pb")
				g := gen.NewGeneratedFile(filename, f.GoImportPath)
				g.P(greeting)
			}
		}
		return nil
	})
}
