package vacation

import (
	"fmt"
	"path/filepath"
	"strings"
)

type link struct {
	name string
	path string
}

func sortLinks(symlinks []link) ([]link, error) {
	// Create a map of all of the symlink names and where they are pointing to to
	// act as a quasi-graph
	index := map[string]string{}
	for _, s := range symlinks {
		index[filepath.Clean(s.path)] = s.name
	}

	// Check to see if the link name lies on the path of another symlink in
	// the table or if it is another symlink in the table
	//
	// Example:
	// path = dir/file
	// a-symlink -> dir
	// b-symlink -> a-symlink
	// c-symlink -> a-symlink/file
	shouldSkipLink := func(linkname, linkpath string) bool {
		sln := strings.Split(linkname, "/")
		for j := 0; j < len(sln); j++ {
			if _, ok := index[linknameFullPath(linkpath, filepath.Join(sln[:j+1]...))]; ok {
				return true
			}
		}
		return false
	}

	// Iterate over the symlink map for every link that is found this ensures
	// that all symlinks that can be created will be created and any that are
	// left over are cyclically dependent
	var links []link
	maxIterations := len(index)
	for i := 0; i < maxIterations; i++ {
		for path, name := range index {
			// If there is a match either of the symlink or it is on the path then
			// skip the creation of this symlink for now
			if shouldSkipLink(name, path) {
				continue
			}

			links = append(links, link{
				name: name,
				path: path,
			})

			// Remove the created symlink from the symlink table so that its
			// dependent symlinks can be created in the next iteration
			delete(index, path)
			break
		}
	}

	// Check to see if there are any symlinks left in the map which would
	// indicate a cyclical dependency
	if len(index) > 0 {
		return nil, fmt.Errorf("failed: max iterations reached: this link graph contains a cycle")
	}

	return links, nil
}
