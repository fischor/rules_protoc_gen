package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/protobuf/compiler/protogen"
)

var (
	flags flag.FlagSet
)

func main() {
	configPath := flags.String("config", "", "")

	protogen.Options{ParamFunc: flags.Set}.Run(func(gen *protogen.Plugin) error {
		conf, err := bazel.Runfile(*configPath)
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
				filename := strings.ReplaceAll(*f.Proto.Name, ".proto", ".data.pb")
				g := gen.NewGeneratedFile(filename, f.GoImportPath)
				g.P(greeting)
			}
		}
		return nil
	})
}
