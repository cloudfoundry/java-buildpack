package supply_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestSupply(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Supply Suite")
}
