package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/infamousjoeg/cyberark-aam-pkiaas/internal/backend"
	"github.com/infamousjoeg/cyberark-aam-pkiaas/internal/backend/conjur"
	"github.com/infamousjoeg/cyberark-aam-pkiaas/pkg/log"
	"github.com/infamousjoeg/cyberark-aam-pkiaas/pkg/pkiaas"
)

var storage backend.Storage

func init() {
	version := flag.Bool("v", false, "Display current version")
	debug := flag.Bool("debug", false, "Enable debug log level")

	flag.Parse()

	// -v flag detected
	if *version {
		fmt.Printf("pkiaas v%s\n", pkiaas.FullVersionName)
		os.Exit(1)
	}

	// -debug flag detected
	if *debug {
		log.EnableDebugMode()
	}

	pkiclient, err := conjur.NewFromDefaults()
	if err != nil {
		panic("Error initializing PKI backend: " + err.Error())
	}

	err = pkiclient.InitConfig()
	if err != nil {
		panic("Error initializing PKI configuration: " + err.Error())
	}

	storage = pkiclient
}
