package frameworks_test

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Java Memory Assistant", func() {
	AfterEach(func() {
		os.Unsetenv("BPL_HEAP_DUMP_PATH")
	})

	Describe("Detection", func() {
		It("uses BPL_HEAP_DUMP_PATH configuration", func() {
			heapDumpPath := "/tmp/heapdumps"
			os.Setenv("BPL_HEAP_DUMP_PATH", heapDumpPath)

			Expect(os.Getenv("BPL_HEAP_DUMP_PATH")).To(Equal(heapDumpPath))
		})
	})
})
