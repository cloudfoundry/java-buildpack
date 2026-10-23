package jres

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

const blockedCertsAlgorithm = "SHA-256"

// blockedCertsFiles are the locations of the JRE's blocked certificates file relative to JAVA_HOME:
// JDK 11+ first, then the Java 8 JRE and JDK layouts.
var blockedCertsFiles = []string{
	filepath.Join("lib", "security", "blocked.certs"),
	filepath.Join("lib", "security", "blacklisted.certs"),
	filepath.Join("jre", "lib", "security", "blacklisted.certs"),
}

type blockedCertsConfig struct {
	Enabled bool `yaml:"enabled"`
}

// ApplyBlockedCerts adds the fingerprints from the embedded jre/blocked.certs resource to the JRE's
// blocked certificates file, so certificates distrusted by OpenJDK are also blocked by JREs that do not
// include that change yet. Existing entries are kept and fingerprints already present are skipped.
// Disable with JBP_CONFIG_JRE_BLOCKED_CERTS='{enabled: false}'.
func ApplyBlockedCerts(ctx *common.Context, javaHome string) error {
	config := blockedCertsConfig{Enabled: true}
	if raw := os.Getenv("JBP_CONFIG_JRE_BLOCKED_CERTS"); raw != "" {
		yamlHandler := common.YamlHandler{}
		if err := yamlHandler.ValidateFields([]byte(raw), &config); err != nil {
			ctx.Log.Warning("Unknown user config values: %s", err.Error())
		}
		if err := yamlHandler.Unmarshal([]byte(raw), &config); err != nil {
			ctx.Log.Warning("Failed to parse JBP_CONFIG_JRE_BLOCKED_CERTS, keeping blocked certificates enabled: %s", err.Error())
			config = blockedCertsConfig{Enabled: true}
		}
	}
	if !config.Enabled {
		ctx.Log.Debug("Blocked certificates update disabled by JBP_CONFIG_JRE_BLOCKED_CERTS")
		return nil
	}

	path := ""
	for _, candidate := range blockedCertsFiles {
		if _, err := os.Stat(filepath.Join(javaHome, candidate)); err == nil {
			path = filepath.Join(javaHome, candidate)
			break
		}
	}
	if path == "" {
		ctx.Log.Debug("No blocked certificates file found in %s, skipping", javaHome)
		return nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", path, err)
	}
	algorithm, present := parseBlockedCerts(string(data))
	if !strings.EqualFold(algorithm, blockedCertsAlgorithm) {
		ctx.Log.Warning("Not updating %s: algorithm %q, expected %s", filepath.Base(path), algorithm, blockedCertsAlgorithm)
		return nil
	}

	embedded, err := resources.GetResource("jre/blocked.certs")
	if err != nil {
		return err
	}
	_, fingerprints := parseBlockedCerts(string(embedded))

	existing := make(map[string]bool, len(present))
	for _, fingerprint := range present {
		existing[fingerprint] = true
	}
	var missing []string
	for _, fingerprint := range fingerprints {
		if !existing[fingerprint] {
			missing = append(missing, fingerprint)
			existing[fingerprint] = true
		}
	}
	if len(missing) == 0 {
		ctx.Log.Info("%s already contains all blocked certificates", filepath.Base(path))
		return nil
	}

	// Append rather than rewrite, so a failed write cannot drop vendor entries.
	addition := strings.Join(missing, "\n") + "\n"
	if len(data) > 0 && data[len(data)-1] != '\n' {
		addition = "\n" + addition
	}
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("failed to stat %s: %w", path, err)
	}
	if mode := info.Mode().Perm(); mode&0200 == 0 {
		if err := os.Chmod(path, mode|0200); err != nil {
			return fmt.Errorf("failed to make %s writable: %w", path, err)
		}
		defer os.Chmod(path, mode)
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		return fmt.Errorf("failed to open %s: %w", path, err)
	}
	if _, err := f.WriteString(addition); err != nil {
		f.Close()
		return fmt.Errorf("failed to write %s: %w", path, err)
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("failed to write %s: %w", path, err)
	}

	ctx.Log.Info("Added %d certificate(s) to %s", len(missing), filepath.Base(path))
	return nil
}

// parseBlockedCerts returns the Algorithm value and the fingerprints, in file order, of a blocked.certs file.
func parseBlockedCerts(content string) (string, []string) {
	algorithm := ""
	var fingerprints []string
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		switch {
		case line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "!"):
		case isProperty(line, "Algorithm"):
			algorithm = propertyValue(line, "Algorithm")
		default:
			fingerprints = append(fingerprints, strings.ToUpper(line))
		}
	}
	return algorithm, fingerprints
}

// isProperty reports whether a trimmed java.util.Properties line has the given key,
// which ends at the first '=', ':' or whitespace.
func isProperty(line, key string) bool {
	rest, found := strings.CutPrefix(line, key)
	return found && rest != "" && strings.ContainsRune("=: \t\f", rune(rest[0]))
}

// propertyValue returns the value of a trimmed java.util.Properties line with the given key.
func propertyValue(line, key string) string {
	rest := strings.TrimLeft(strings.TrimPrefix(line, key), " \t\f")
	if rest != "" && (rest[0] == '=' || rest[0] == ':') {
		rest = rest[1:]
	}
	return strings.TrimSpace(rest)
}
