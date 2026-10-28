package jres

import (
	"bufio"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/pem"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/cloudfoundry/java-buildpack/src/java/common"
	"github.com/cloudfoundry/java-buildpack/src/java/resources"
)

const (
	cacertsPassword = "changeit"
	keytoolTimeout  = 60 * time.Second
)

// cacertsFiles are the locations of the JRE's trust store relative to JAVA_HOME:
// JDK 11+ first, then the Java 8 JRE layout.
var cacertsFiles = []string{
	filepath.Join("lib", "security", "cacerts"),
	filepath.Join("jre", "lib", "security", "cacerts"),
}

// keytoolFiles are the locations of keytool relative to JAVA_HOME.
var keytoolFiles = []string{
	filepath.Join("bin", "keytool"),
	filepath.Join("jre", "bin", "keytool"),
}

type removedRootsConfig struct {
	Enabled bool `yaml:"enabled"`
}

// RemoveDistrustedRoots deletes the root certificates listed in the embedded jre/removed-roots.certs
// resource from the JRE's cacerts, so roots removed by newer JREs are also gone from older ones.
// Certificates are matched by SHA-256 fingerprint, so vendor alias names do not matter.
// Disable with JBP_CONFIG_JRE_REMOVED_ROOTS='{enabled: false}'.
func RemoveDistrustedRoots(ctx *common.Context, javaHome string) error {
	config := removedRootsConfig{Enabled: true}
	if raw := os.Getenv("JBP_CONFIG_JRE_REMOVED_ROOTS"); raw != "" {
		yamlHandler := common.YamlHandler{}
		if err := yamlHandler.ValidateFields([]byte(raw), &config); err != nil {
			ctx.Log.Warning("Unknown user config values: %s", err.Error())
		}
		if err := yamlHandler.Unmarshal([]byte(raw), &config); err != nil {
			ctx.Log.Warning("Failed to parse JBP_CONFIG_JRE_REMOVED_ROOTS, keeping root removal enabled: %s", err.Error())
			config = removedRootsConfig{Enabled: true}
		}
	}
	if !config.Enabled {
		ctx.Log.Debug("Removal of distrusted roots disabled by JBP_CONFIG_JRE_REMOVED_ROOTS")
		return nil
	}

	cacerts := firstExisting(javaHome, cacertsFiles)
	if cacerts == "" {
		ctx.Log.Debug("No cacerts found in %s, skipping", javaHome)
		return nil
	}
	keytool := firstExisting(javaHome, keytoolFiles)
	if keytool == "" {
		ctx.Log.Warning("Not removing distrusted roots from cacerts: no keytool found in %s", javaHome)
		return nil
	}

	embedded, err := resources.GetResource("jre/removed-roots.certs")
	if err != nil {
		return err
	}
	algorithm, fingerprints := parseBlockedCerts(string(embedded))
	if !strings.EqualFold(algorithm, blockedCertsAlgorithm) {
		return fmt.Errorf("unexpected algorithm %q in removed-roots.certs", algorithm)
	}
	removed := make(map[string]bool, len(fingerprints))
	for _, fingerprint := range fingerprints {
		removed[fingerprint] = true
	}

	listing, err := runKeytool(keytool, "-list", "-rfc", "-keystore", cacerts, "-storepass", cacertsPassword)
	if err != nil {
		return fmt.Errorf("failed to list %s: %w", cacerts, err)
	}
	var aliases []string
	for _, entry := range parseKeytoolCertificates(listing) {
		if removed[entry.fingerprint] {
			aliases = append(aliases, entry.alias)
		}
	}
	if len(aliases) == 0 {
		ctx.Log.Info("cacerts already free of the removed root certificates")
		return nil
	}

	info, err := os.Stat(cacerts)
	if err != nil {
		return fmt.Errorf("failed to stat %s: %w", cacerts, err)
	}
	if mode := info.Mode().Perm(); mode&0200 == 0 {
		if err := os.Chmod(cacerts, mode|0200); err != nil {
			return fmt.Errorf("failed to make %s writable: %w", cacerts, err)
		}
		defer os.Chmod(cacerts, mode)
	}

	count := 0
	for _, alias := range aliases {
		if _, err := runKeytool(keytool, "-delete", "-alias", alias, "-keystore", cacerts, "-storepass", cacertsPassword); err != nil {
			ctx.Log.Warning("Could not remove %q from cacerts: %s", alias, err.Error())
			continue
		}
		count++
	}
	ctx.Log.Info("Removed %d root certificate(s) from cacerts", count)
	return nil
}

func firstExisting(javaHome string, candidates []string) string {
	for _, candidate := range candidates {
		path := filepath.Join(javaHome, candidate)
		if info, err := os.Stat(path); err == nil && !info.IsDir() {
			return path
		}
	}
	return ""
}

// runKeytool forces English output, as the alias lines of a listing are localized.
func runKeytool(keytool string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), keytoolTimeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, keytool, append([]string{"-J-Duser.language=en"}, args...)...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%w: %s", err, strings.TrimSpace(string(output)))
	}
	return string(output), nil
}

type keystoreCertificate struct {
	alias       string
	fingerprint string
}

// parseKeytoolCertificates returns the alias and SHA-256 fingerprint of each certificate in the
// output of keytool -list -rfc.
func parseKeytoolCertificates(listing string) []keystoreCertificate {
	var certificates []keystoreCertificate
	var alias string
	var block strings.Builder
	inBlock := false

	scanner := bufio.NewScanner(strings.NewReader(listing))
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimRight(scanner.Text(), "\r")
		switch {
		case inBlock:
			block.WriteString(line + "\n")
			if strings.HasPrefix(line, "-----END CERTIFICATE-----") {
				inBlock = false
				if decoded, _ := pem.Decode([]byte(block.String())); decoded != nil {
					sum := sha256.Sum256(decoded.Bytes)
					certificates = append(certificates, keystoreCertificate{alias, strings.ToUpper(hex.EncodeToString(sum[:]))})
				}
			}
		case strings.HasPrefix(line, "Alias name: "):
			alias = strings.TrimPrefix(line, "Alias name: ")
		case strings.HasPrefix(line, "-----BEGIN CERTIFICATE-----"):
			inBlock = true
			block.Reset()
			block.WriteString(line + "\n")
		}
	}
	return certificates
}
