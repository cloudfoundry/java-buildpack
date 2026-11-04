package docker

import (
	"cmp"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/paketo-buildpacks/packit/v2/fs"
	"github.com/paketo-buildpacks/packit/v2/vacation"
)

//go:generate faux --interface BPCache --output fakes/bp_cache.go
type BPCache interface {
	Fetch(url string) (io.ReadCloser, error)
}

//go:generate faux --interface BPRegistry --output fakes/bp_registry.go
type BPRegistry interface {
	List() ([]Buildpack, error)
	Override(...Buildpack)
}

type Buildpack struct {
	Name string
	URI  string
}

type BuildpacksManager struct {
	archiver Archiver
	cache    BPCache
	registry BPRegistry

	filter []string
}

func NewBuildpacksManager(archiver Archiver, cache BPCache, registry BPRegistry) BuildpacksManager {
	return BuildpacksManager{
		archiver: archiver,
		cache:    cache,
		registry: registry,
	}
}

// buildpacksBuildMutex serializes tarball creation so parallel tests in one
// process share a single build.
var buildpacksBuildMutex sync.Mutex

const (
	// sharedKeep is the number of most recently used shared tarballs to keep,
	// so tests alternating between buildpack sets do not rebuild every time.
	sharedKeep = 3

	// sharedLeftoverAge is how old an unfinished shared artifact must be before
	// it is removed, so files still in use by other processes are kept.
	sharedLeftoverAge = time.Hour
)

// Build creates the buildpacks tarball once per unique set of buildpacks and
// hard-links it per app. Rebuilding the tarball for every app is very slow for
// large cached buildpacks.
func (m BuildpacksManager) Build(workspace, name string) (string, error) {
	if err := validateName(name); err != nil {
		return "", fmt.Errorf("invalid app name: %w", err)
	}

	buildpacks, err := m.registry.List()
	if err != nil {
		return "", fmt.Errorf("failed to list buildpacks: %w", err)
	}

	var selected []Buildpack
	for _, buildpack := range buildpacks {
		contains := len(m.filter) == 0
		for _, name := range m.filter {
			if buildpack.Name == name {
				contains = true
				break
			}
		}

		if contains {
			selected = append(selected, buildpack)
		}
	}

	output := filepath.Join(workspace, fmt.Sprintf("%s.tar.gz", name))

	// workspace may not exist yet on a fresh installation. The shared path
	// below only creates the sibling sharedDir, so workspace must be created
	// explicitly before linking or copying the shared tarball into it.
	err = os.MkdirAll(workspace, os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to create buildpacks workspace: %w", err)
	}

	key, err := buildpacksKey(selected)
	if err != nil {
		return "", err
	}

	// Shared artifacts live in a directory next to workspace (which holds
	// per-app directories and tarballs named after apps), so an app name --
	// including "shared" itself -- can never collide with the shared
	// tarball directory, its temporary files, or trigger its deletion via
	// Teardown's per-app os.RemoveAll(workspace/<name>).
	sharedDir := filepath.Join(filepath.Dir(workspace), "buildpacks-shared")
	err = os.MkdirAll(sharedDir, os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to create shared buildpacks directory: %w", err)
	}

	shared := filepath.Join(sharedDir, fmt.Sprintf("%s.tar.gz", key))

	buildpacksBuildMutex.Lock()
	defer buildpacksBuildMutex.Unlock()

	err = os.Remove(output)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("failed to remove existing buildpacks tarball: %w", err)
	}

	// Another process may remove the shared tarball between the build and the
	// link, so retry once with a fresh build.
	for attempt := 0; ; attempt++ {
		removeStaleTemp(sharedDir, shared)

		if _, err := os.Stat(shared); err != nil {
			err = m.buildShared(sharedDir, key, shared, selected)
			if err != nil {
				return "", err
			}
		} else {
			now := time.Now()
			_ = os.Chtimes(shared, now, now)
		}

		err = os.Link(shared, output)
		if err == nil {
			evictOldSharedTarballs(sharedDir)
			return output, nil
		}

		err = fs.Copy(shared, output)
		if err == nil {
			evictOldSharedTarballs(sharedDir)
			return output, nil
		}

		if attempt > 0 || !errors.Is(err, os.ErrNotExist) {
			return "", fmt.Errorf("failed to link buildpacks tarball: %w", err)
		}
	}
}

// buildpacksKey identifies a set of buildpacks by name and URI and, for local
// files or directories, by the size and modification time of their contents.
func buildpacksKey(buildpacks []Buildpack) (string, error) {
	// The registry lists overridden buildpacks in random order, and the order
	// does not affect the tarball content.
	sorted := slices.Clone(buildpacks)
	slices.SortFunc(sorted, func(a, b Buildpack) int {
		return cmp.Or(cmp.Compare(a.Name, b.Name), cmp.Compare(a.URI, b.URI))
	})

	hash := sha256.New()
	for _, buildpack := range sorted {
		identity := buildpack.URI

		// BuildpacksCache.Fetch treats a URI without a URL scheme as a local
		// path and opens it relative to the current working directory. Two
		// processes with different working directories can supply the same
		// relative path for different files, so key on the absolute path for
		// local buildpacks to avoid a false cache hit. Remote URIs are
		// already globally unambiguous and are kept as-is.
		if u, err := url.Parse(buildpack.URI); err == nil && !u.IsAbs() {
			abs, err := filepath.Abs(buildpack.URI)
			if err != nil {
				return "", fmt.Errorf("failed to resolve buildpack path: %w", err)
			}

			identity = abs

			// Abs cleans ".." lexically, but the filesystem resolves it
			// after following symlinks, so key on the resolved path when
			// the file exists.
			if real, err := filepath.EvalSymlinks(buildpack.URI); err == nil {
				if identity, err = filepath.Abs(real); err != nil {
					return "", fmt.Errorf("failed to resolve buildpack path: %w", err)
				}
			}
		}

		fmt.Fprintf(hash, "%s|%s\n", buildpack.Name, identity)

		info, err := os.Stat(buildpack.URI)
		if err != nil {
			continue
		}

		if !info.IsDir() {
			fmt.Fprintf(hash, "%d|%d\n", info.Size(), info.ModTime().UnixNano())
			continue
		}

		// os.Stat follows symlinks, so a symlinked buildpack directory is
		// classified as a directory here. filepath.Walk uses Lstat though,
		// and would only visit the symlink itself, leaving the key unchanged
		// when files beneath the real target change. Walk the resolved path.
		root, err := filepath.EvalSymlinks(buildpack.URI)
		if err != nil {
			return "", fmt.Errorf("failed to resolve buildpack directory: %w", err)
		}

		err = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			rel, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}

			fmt.Fprintf(hash, "%s|%d|%d|%s\n", rel, info.Size(), info.ModTime().UnixNano(), info.Mode())
			return nil
		})
		if err != nil {
			return "", fmt.Errorf("failed to scan buildpack directory: %w", err)
		}
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}

// removeStaleTemp removes temporary staging directories and tmp files older
// than sharedLeftoverAge, left behind by a killed process. Recent temporary
// files may belong to a concurrent build in another process and are kept.
// sharedDir is a directory dedicated to shared artifacts, so entries here
// cannot collide with per-app tarball names.
func removeStaleTemp(sharedDir, shared string) {
	paths, _ := filepath.Glob(filepath.Join(sharedDir, "*"))

	for _, path := range paths {
		if path == shared || strings.HasSuffix(path, ".tar.gz") {
			continue
		}

		info, err := os.Stat(path)
		if err != nil {
			continue
		}

		if time.Since(info.ModTime()) > sharedLeftoverAge {
			_ = os.RemoveAll(path)
		}
	}
}

// evictOldSharedTarballs keeps the sharedKeep most recently used shared
// tarballs and removes older ones. It runs after a build successfully
// publishes and links its own tarball, so eviction accounts for every
// tarball concurrent processes have already published, rather than
// pruning against a snapshot taken before publication that could let
// several concurrent cache misses each publish past the retention limit.
func evictOldSharedTarballs(sharedDir string) {
	paths, _ := filepath.Glob(filepath.Join(sharedDir, "*.tar.gz"))

	type tarball struct {
		path    string
		modTime time.Time
	}

	var finished []tarball
	for _, path := range paths {
		info, err := os.Stat(path)
		if err != nil {
			continue
		}

		finished = append(finished, tarball{path: path, modTime: info.ModTime()})
	}

	sort.Slice(finished, func(i, j int) bool {
		return finished[i].modTime.After(finished[j].modTime)
	})

	for i, t := range finished {
		if i >= sharedKeep {
			_ = os.Remove(t.path)
		}
	}
}

func (m BuildpacksManager) buildShared(sharedDir, key, shared string, buildpacks []Buildpack) error {
	unique := fmt.Sprintf("%d-%d", os.Getpid(), time.Now().UnixNano())
	staging := filepath.Join(sharedDir, fmt.Sprintf("%s.%s.staging", key, unique))
	defer os.RemoveAll(staging)

	tmp := fmt.Sprintf("%s.%s.tmp", shared, unique)
	err := m.buildTarball(staging, tmp, buildpacks)
	if err != nil {
		_ = os.Remove(tmp)
		return err
	}

	err = os.Rename(tmp, shared)
	if err != nil {
		// On Windows, Rename cannot replace an existing destination. If a
		// concurrent process already published the shared tarball, discard
		// this build and reuse the winner instead of failing; the caller's
		// link retry handles the shared file disappearing afterwards.
		if _, statErr := os.Stat(shared); statErr == nil {
			_ = os.Remove(tmp)
			return nil
		}

		_ = os.Remove(tmp)
		return fmt.Errorf("failed to store buildpacks tarball: %w", err)
	}

	return nil
}

func (m BuildpacksManager) buildTarball(staging, output string, buildpacks []Buildpack) error {
	err := os.RemoveAll(staging)
	if err != nil {
		return fmt.Errorf("failed to remove existing buildpack directory: %w", err)
	}

	err = os.MkdirAll(staging, os.ModePerm)
	if err != nil {
		return fmt.Errorf("failed to create buildpack directory: %w", err)
	}

	for _, buildpack := range buildpacks {
		bp, err := m.cache.Fetch(buildpack.URI)
		if err != nil {
			return fmt.Errorf("failed to fetch buildpack: %w", err)
		}

		var isDir bool
		if file, ok := bp.(interface{ Stat() (os.FileInfo, error) }); ok {
			info, err := file.Stat()
			if err != nil {
				return fmt.Errorf("failed to stat buildpack: %w", err)
			}

			isDir = info.IsDir()
		}

		destination := filepath.Join(staging, fmt.Sprintf("%x", md5.Sum([]byte(buildpack.Name))))

		if isDir {
			// filepath.Walk (used internally by fs.Copy) does not follow
			// symbolic links, so a symlinked buildpack.URI would only
			// yield a single symlink entry instead of its contents.
			// Resolve to the real path first, matching buildpacksKey.
			source, err := filepath.EvalSymlinks(buildpack.URI)
			if err != nil {
				return fmt.Errorf("failed to resolve buildpack directory: %w", err)
			}

			err = fs.Copy(source, destination)
			if err != nil {
				return fmt.Errorf("failed to copy buildpack: %w", err)
			}
		} else {
			err = vacation.NewZipArchive(bp).Decompress(destination)
			if err != nil {
				return fmt.Errorf("failed to decompress buildpack: %w", err)
			}
		}

		err = bp.Close()
		if err != nil {
			return fmt.Errorf("failed to close buildpack: %w", err)
		}
	}

	err = m.archiver.WithPrefix("/tmp/buildpacks").Compress(staging, output)
	if err != nil {
		return fmt.Errorf("failed to archive buildpacks: %w", err)
	}

	return nil
}

func (m BuildpacksManager) Order() (string, bool, error) {
	var names []string
	buildpacks, err := m.registry.List()
	if err != nil {
		return "", false, fmt.Errorf("failed to list buildpacks: %w", err)
	}

	if len(m.filter) > 0 {
		names = m.filter
	} else {
		for _, buildpack := range buildpacks {
			names = append(names, buildpack.Name)
		}
	}

	return strings.Join(names, ","), len(m.filter) > 0, nil
}

func (m BuildpacksManager) WithBuildpacks(buildpacks ...string) BuildpacksBuilder {
	m.filter = buildpacks
	return m
}
