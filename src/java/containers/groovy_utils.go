package containers

import (
	"os"
	"path/filepath"
	"regexp"
)

// GroovyUtils provides utilities for analyzing Groovy files
// This matches the functionality from the Ruby buildpack's groovy_utils.rb

var (
	// Regex patterns for Groovy file analysis
	mainMethodPattern = regexp.MustCompile(`static\s+void\s+main\s*\(`)
	pogoPattern       = regexp.MustCompile(`class\s+\w+[\s\w]*\{`)
	shebangPattern    = regexp.MustCompile(`^#!`)
	beansPattern      = regexp.MustCompile(`beans\s*\{`)
	logbackPattern    = regexp.MustCompile(`ch/qos/logback/.*\.groovy$`)
)

// GroovyUtils struct provides instance methods for SpringBootCLI compatibility
type GroovyUtils struct{}

// FindGroovyFiles finds all .groovy files in the given directory
func (g *GroovyUtils) FindGroovyFiles(dir string) ([]string, error) {
	var groovyFiles []string
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && filepath.Ext(path) == ".groovy" {
			groovyFiles = append(groovyFiles, path)
		}
		return nil
	})
	return groovyFiles, err
}

// IsLogbackConfigFile checks if a file is a logback configuration file
func (g *GroovyUtils) IsLogbackConfigFile(filePath string) bool {
	return logbackPattern.MatchString(filePath)
}

// HasMainMethod checks if a Groovy file contains a static void main() method
func (g *GroovyUtils) HasMainMethod(filePath string) bool {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return false
	}
	return mainMethodPattern.Match(content)
}

// IsPOGO checks if a Groovy file is a Plain Old Groovy Object (contains a class definition)
func (g *GroovyUtils) IsPOGO(filePath string) bool {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return false
	}
	return pogoPattern.Match(content)
}

// HasShebang checks if a Groovy file has a shebang line (#!/...)
func (g *GroovyUtils) HasShebang(filePath string) bool {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return false
	}
	return shebangPattern.Match(content)
}

// IsBeans checks if a Groovy file is a beans-style configuration
func (g *GroovyUtils) IsBeans(filePath string) bool {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return false
	}
	return beansPattern.Match(content)
}

// isValidGroovyFile checks if a file is a valid, readable Groovy script
// Filters out binary files, empty files, and files with invalid content
func isValidGroovyFile(filePath string) bool {
	info, err := os.Stat(filePath)
	if err != nil {
		return false
	}

	// Skip empty or very small files (likely invalid)
	if info.Size() < 10 {
		return false
	}

	// Try to read the file
	content, err := os.ReadFile(filePath)
	if err != nil {
		return false
	}

	// Check if content is valid UTF-8 and not binary
	// Binary files or invalid groovy files will fail this check
	for i, b := range content {
		// Allow common text characters and control chars (newlines, tabs, etc.)
		if b < 9 || (b > 13 && b < 32 && b != 27) || b == 127 {
			// Check if it's part of a valid UTF-8 sequence
			if !isPartOfUTF8Sequence(content, i) {
				return false
			}
		}
	}

	return true
}

// isPartOfUTF8Sequence checks if a byte at position i is part of a valid UTF-8 sequence
func isPartOfUTF8Sequence(content []byte, i int) bool {
	// Simple check: if byte has high bit set, it should be part of UTF-8
	if content[i] >= 128 {
		// Basic UTF-8 validation - this is a simplified check
		return true
	}
	return false
}

// FindMainGroovyScript determines which Groovy script should be executed.
// Following Ruby buildpack logic, a file is a candidate if it has a static
// void main() method, is not a POGO, or has a shebang.
// Returns the single candidate if exactly one matches, empty string otherwise.
func FindMainGroovyScript(scripts []string) (string, error) {
	g := &GroovyUtils{}
	candidates := make(map[string]bool)

	for _, script := range scripts {
		if !isValidGroovyFile(script) {
			continue
		}
		if g.HasMainMethod(script) || !g.IsPOGO(script) || g.HasShebang(script) {
			candidates[script] = true
		}
	}

	if len(candidates) == 1 {
		for script := range candidates {
			return script, nil
		}
	}

	return "", nil
}
