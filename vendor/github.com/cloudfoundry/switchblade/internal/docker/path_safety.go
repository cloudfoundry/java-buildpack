package docker

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// reservedNames are directory entries BuildpacksManager and Teardown use for
// bookkeeping that spans every app, not a single one. An app must never use
// one of these as its own name: structural placement (shared bookkeeping
// paths now live outside the per-app directory tree) already prevents a
// collision, but rejecting the name outright is a cheap second line of
// defense if that placement ever changes.
var reservedNames = map[string]bool{
	"shared":            true,
	"buildpacks-shared": true,
}

// validateName rejects app names that are unsafe to join into a workspace
// path: empty names, "." and "..", names containing a path separator (which
// could escape the intended per-app directory, e.g. "../../etc"), and
// reserved bookkeeping names.
func validateName(name string) error {
	if name == "" {
		return errors.New("name must not be empty")
	}

	if name == "." || name == ".." {
		return fmt.Errorf("name must not be %q", name)
	}

	if strings.ContainsAny(name, `/\`) {
		return fmt.Errorf("name must not contain a path separator: %q", name)
	}

	if reservedNames[name] {
		return fmt.Errorf("name %q is reserved", name)
	}

	return nil
}

// removeAllWithin removes target, but only if target is actually nested
// inside base. This guards a destructive recursive removal against a future
// change that weakens name validation and lets a crafted name escape the
// intended directory, or against target equaling base itself.
func removeAllWithin(base, target string) error {
	base = filepath.Clean(base)
	target = filepath.Clean(target)

	rel, err := filepath.Rel(base, target)
	if err != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return fmt.Errorf("refusing to remove %q: not inside %q", target, base)
	}

	return os.RemoveAll(target)
}
