package jres_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestJREs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "JREs Suite")
}
