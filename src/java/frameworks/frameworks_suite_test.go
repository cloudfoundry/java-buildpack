package frameworks_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestFrameworks(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Frameworks Suite")
}
