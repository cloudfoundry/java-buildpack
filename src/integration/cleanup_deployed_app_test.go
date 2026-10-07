package integration_test

import (
	"errors"
	"testing"

	"github.com/cloudfoundry/switchblade"

	. "github.com/onsi/gomega"
)

// cleanupDeployedApp deletes the app/container created by a test. Skipped tests never
// deployed anything, and on the cf platform deleting a never-deployed app fails
// ("No API endpoint set"), so they are not cleaned up.
func cleanupDeployedApp(t *testing.T, platform switchblade.Platform, name string) {
	t.Helper()

	if t.Failed() && name != "" {
		t.Logf("❌ FAILED TEST - App/Container: %s", name)
		t.Logf("   Platform: %s", settings.Platform)
	}
	if name != "" && !t.Skipped() && (!settings.KeepFailedContainers || !t.Failed()) {
		NewWithT(t).Expect(platform.Delete.Execute(name)).To(Succeed())
	}
}

type fakeDelete struct {
	calls []string
	err   error
}

func (f *fakeDelete) Execute(name string) error {
	f.calls = append(f.calls, name)
	return f.err
}

func TestCleanupDeployedApp(t *testing.T) {
	t.Run("does not delete when the test was skipped", func(t *testing.T) {
		// like the cf platform, which fails to delete a never-deployed app
		del := &fakeDelete{err: errors.New("failed to delete-org: No API endpoint set")}
		t.Run("skipped", func(t *testing.T) {
			defer cleanupDeployedApp(t, switchblade.Platform{Delete: del}, "app")
			t.Skip("skipped")
		})
		NewWithT(t).Expect(del.calls).To(BeEmpty())
	})

	t.Run("deletes when the test ran", func(t *testing.T) {
		del := &fakeDelete{}
		cleanupDeployedApp(t, switchblade.Platform{Delete: del}, "app")
		NewWithT(t).Expect(del.calls).To(Equal([]string{"app"}))
	})

	t.Run("does not delete without a name", func(t *testing.T) {
		del := &fakeDelete{}
		cleanupDeployedApp(t, switchblade.Platform{Delete: del}, "")
		NewWithT(t).Expect(del.calls).To(BeEmpty())
	})
}
