package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"path"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/protobuf/compiler/protogen"
)

var flags flag.FlagSet
var opts Options

type Options struct {
	TestData string
}

func (o *Options) AddFlags(fs *flag.FlagSet) {
	fs.StringVar(&o.TestData, "testdata", "", "")
}

func main() {
	opts.AddFlags(&flags)
	protogen.Options{ParamFunc: flags.Set}.Run(generate)
}

func generate(gen *protogen.Plugin) error {
	if opts.TestData == "" {
		return fmt.Errorf("option \"testdata\" is required")
	}
	filename, err := bazel.Runfile(opts.TestData)
	if err != nil {
		return err
	}
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}
	// Stripping newlines to avoid incompatibilies with unix systems and windows.
	content := strings.TrimSpace(string(data))
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
		g.P(content)
	}
	return nil
}
