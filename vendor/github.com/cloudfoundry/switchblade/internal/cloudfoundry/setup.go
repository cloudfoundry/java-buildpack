package cloudfoundry

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/paketo-buildpacks/packit/v2/fs"
	"github.com/paketo-buildpacks/packit/v2/pexec"
)

type SetupPhase interface {
	Run(logs io.Writer, home, name, source string) (url string, err error)

	WithBuildpacks(buildpacks ...string) SetupPhase
	WithStack(stack string) SetupPhase
	WithEnv(env map[string]string) SetupPhase
	WithoutInternetAccess() SetupPhase
	WithServices(services map[string]map[string]interface{}) SetupPhase
	WithStartCommand(command string) SetupPhase
	WithHealthCheckType(healthCheckType string) SetupPhase
}

type Setup struct {
	cli  Executable
	home string

	internetAccess  bool
	buildpacks      []string
	stack           string
	env             map[string]string
	services        map[string]map[string]interface{}
	lookupHost      func(string) ([]string, error)
	startCommand    string
	healthCheckType string
}

func NewSetup(cli Executable, home, stack string) Setup {
	return Setup{
		cli:            cli,
		home:           home,
		internetAccess: true,
		lookupHost:     net.LookupHost,
		stack:          stack,
	}
}

func (s Setup) WithBuildpacks(buildpacks ...string) SetupPhase {
	s.buildpacks = buildpacks
	return s
}

func (s Setup) WithStack(stack string) SetupPhase {
	s.stack = stack
	return s
}

func (s Setup) WithEnv(env map[string]string) SetupPhase {
	s.env = env
	return s
}

func (s Setup) WithoutInternetAccess() SetupPhase {
	s.internetAccess = false
	return s
}

func (s Setup) WithServices(services map[string]map[string]interface{}) SetupPhase {
	s.services = services
	return s
}

func (s Setup) WithCustomHostLookup(lookupHost func(string) ([]string, error)) Setup {
	s.lookupHost = lookupHost
	return s
}

func (s Setup) WithStartCommand(command string) SetupPhase {
	s.startCommand = command
	return s
}

func (s Setup) WithHealthCheckType(healthCheckType string) SetupPhase {
	s.healthCheckType = healthCheckType
	return s
}

func (s Setup) Run(log io.Writer, home, name, source string) (string, error) {
	err := os.MkdirAll(home, os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("failed to make temporary $CF_HOME: %w", err)
	}

	err = os.RemoveAll(filepath.Join(home, ".cf"))
	if err != nil {
		return "", fmt.Errorf("failed to clear temporary $CF_HOME: %w", err)
	}

	err = fs.Copy(s.home, filepath.Join(home, ".cf"))
	if err != nil {
		return "", fmt.Errorf("failed to copy $CF_HOME: %w", err)
	}

	env := append(os.Environ(), fmt.Sprintf("CF_HOME=%s", home))
	buffer := bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"curl", "/v3/domains"},
		Stdout: io.MultiWriter(log, buffer),
		Stderr: io.MultiWriter(log, buffer),
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to curl /v3/domains: %w\n\nOutput:\n%s", err, log)
	}

	var domains struct {
		Resources []struct {
			Name     string `json:"name"`
			Internal bool   `json:"internal"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&domains)
	if err != nil {
		return "", fmt.Errorf("failed to parse domains: %w", err)
	}

	var domain string
	for _, dom := range domains.Resources {
		if !dom.Internal {
			domain = strings.TrimPrefix(dom.Name, "apps.")
			break
		}
	}

	var domainExists bool
	for _, dom := range domains.Resources {
		if dom.Name == fmt.Sprintf("tcp.%s", domain) {
			domainExists = true
			break
		}
	}

	if !domainExists {
		buffer = bytes.NewBuffer(nil)
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"curl", "/routing/v1/router_groups"},
			Stdout: io.MultiWriter(log, buffer),
			Stderr: io.MultiWriter(log, buffer),
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to curl /routing/v1/router_groups: %w\n\nOutput:\n%s", err, log)
		}

		var routerGroups []struct {
			Name string `json:"name"`
			Type string `json:"type"`
		}
		err = json.NewDecoder(buffer).Decode(&routerGroups)
		if err != nil {
			return "", fmt.Errorf("failed to parse router groups: %w", err)
		}

		var routerGroup string
		for _, group := range routerGroups {
			if group.Type == "tcp" {
				routerGroup = group.Name
				break
			}
		}

		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"create-shared-domain", fmt.Sprintf("tcp.%s", domain), "--router-group", routerGroup},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			logStr := log.(*bytes.Buffer).String()
			if strings.Contains(logStr, "already in use") {
				fmt.Fprintf(log, "TCP domain already exists, continuing...\n")
			} else {
				return "", fmt.Errorf("failed to create-shared-domain: %w\n\nOutput:\n%s", err, log)
			}
		}
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"create-org", name},
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to create-org: %w\n\nOutput:\n%s", err, log)
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"create-space", name, "-o", name},
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to create-space: %w\n\nOutput:\n%s", err, log)
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"target", "-o", name, "-s", name},
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to target: %w\n\nOutput:\n%s", err, log)
	}

	configFile, err := os.Open(filepath.Join(home, ".cf", "config.json"))
	if err != nil {
		return "", err
	}
	defer configFile.Close()

	var config struct {
		Target string
	}
	err = json.NewDecoder(configFile).Decode(&config)
	if err != nil {
		return "", err
	}

	target, err := url.Parse(config.Target)
	if err != nil {
		return "", err
	}

	securityGroup := PublicSecurityGroup
	if !s.internetAccess {
		securityGroup = PrivateSecurityGroup
	}

	for _, fqdn := range []string{target.Host, fmt.Sprintf("tcp.%s", domain)} {
		addrs, err := s.lookupHost(fqdn)
		if err != nil {
			return "", err
		}

		for _, addr := range addrs {
			if !strings.Contains(addr, ":") {
				securityGroup = append(securityGroup, SecurityGroupRule{
					Destination: addr,
					Protocol:    "all",
				})
			}
		}
	}

	content, err := json.Marshal(securityGroup)
	if err != nil {
		return "", err
	}

	err = os.WriteFile(filepath.Join(home, "security-group.json"), content, 0600)
	if err != nil {
		return "", err
	}

	err = os.WriteFile(filepath.Join(home, "empty-security-group.json"), []byte("[]"), 0600)
	if err != nil {
		return "", err
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"create-security-group", name, filepath.Join(home, "security-group.json")},
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to create-security-group: %w\n\nOutput:\n%s", err, log)
	}

	for _, phase := range []string{"staging", "running"} {
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"bind-security-group", name, name, "--space", name, "--lifecycle", phase},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to bind-security-group: %w\n\nOutput:\n%s", err, log)
		}
	}

	buffer = bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"curl", "/v3/security_groups"},
		Stdout: io.MultiWriter(log, buffer),
		Stderr: io.MultiWriter(log, buffer),
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to curl /v3/security_groups: %w\n\nOutput:\n%s", err, log)
	}

	var securityGroups struct {
		Resources []struct {
			Name string `json:"name"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&securityGroups)
	if err != nil {
		return "", fmt.Errorf("failed to parse security groups: %w", err)
	}

	for _, securityGroup := range securityGroups.Resources {
		if !strings.HasPrefix(securityGroup.Name, "switchblade") {
			err = s.cli.Execute(pexec.Execution{
				Args:   []string{"update-security-group", securityGroup.Name, filepath.Join(home, "empty-security-group.json")},
				Stdout: log,
				Stderr: log,
				Env:    env,
			})
			if err != nil {
				return "", fmt.Errorf("failed to update-security-group: %w\n\nOutput:\n%s", err, log)
			}
		}
	}

	args := []string{"push", name, "-p", source, "--no-start", "-s", s.stack}
	for _, buildpack := range s.buildpacks {
		args = append(args, "-b", buildpack)
	}

	if s.startCommand != "" {
		args = append(args, "-c", s.startCommand)
	}

	_, err = os.Stat(filepath.Join(source, "manifest.yml"))
	if err == nil {
		args = append(args, "-f", filepath.Join(source, "manifest.yml"))
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   args,
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to push: %w\n\nOutput:\n%s", err, log)
	}

	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"update-quota", "default", "--reserved-route-ports", "100"},
		Stdout: log,
		Stderr: log,
		Env:    env,
	})
	if err != nil {
		fmt.Fprintf(log, "WARNING: failed to update-quota for TCP routes: %v\n", err)
		fmt.Fprintf(log, "Continuing without TCP route - HTTP routes will still be available\n")
	} else {
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"map-route", name, fmt.Sprintf("tcp.%s", domain)},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			fmt.Fprintf(log, "WARNING: failed to map TCP route: %v\n", err)
			fmt.Fprintf(log, "Continuing without TCP route - HTTP routes will still be available\n")
		}
	}

	buffer = bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"curl", "/v3/spaces"},
		Stdout: io.MultiWriter(log, buffer),
		Stderr: io.MultiWriter(log, buffer),
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to curl /v3/spaces: %w\n\nOutput:\n%s", err, log)
	}

	var spaces struct {
		Resources []struct {
			Name string `json:"name"`
			GUID string `json:"guid"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&spaces)
	if err != nil {
		return "", fmt.Errorf("failed to parse spaces: %w\n\nOutput:\n%s", err, log)
	}

	var spaceGUID string
	for _, space := range spaces.Resources {
		if space.Name == name {
			spaceGUID = space.GUID
			break
		}
	}

	buffer = bytes.NewBuffer(nil)
	err = s.cli.Execute(pexec.Execution{
		Args:   []string{"curl", fmt.Sprintf("/v3/routes?space_guids=%s", spaceGUID)},
		Stdout: io.MultiWriter(log, buffer),
		Stderr: io.MultiWriter(log, buffer),
		Env:    env,
	})
	if err != nil {
		return "", fmt.Errorf("failed to curl /v3/routes: %w\n\nOutput:\n%s", err, log)
	}

	var routes struct {
		Resources []struct {
			Protocol string `json:"protocol"`
			Port     int    `json:"port"`
		} `json:"resources"`
	}
	err = json.NewDecoder(buffer).Decode(&routes)
	if err != nil {
		return "", fmt.Errorf("failed to parse routes: %w\n\nOutput:\n%s", err, log)
	}

	var port int
	for _, route := range routes.Resources {
		if route.Protocol == "tcp" {
			port = route.Port
			break
		}
	}

	var envKeys []string
	for key := range s.env {
		envKeys = append(envKeys, key)
	}
	sort.Strings(envKeys)

	for _, key := range envKeys {
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"set-env", name, key, s.env[key]},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to set-env: %w\n\nOutput:\n%s", err, log)
		}
	}

	if s.healthCheckType != "" {
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"set-health-check", name, s.healthCheckType},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to set-health-check: %w\n\nOutput:\n%s", err, log)
		}
	}

	var serviceKeys []string
	for key := range s.services {
		serviceKeys = append(serviceKeys, key)
	}
	sort.Strings(serviceKeys)

	for _, key := range serviceKeys {
		content, err := json.Marshal(s.services[key])
		if err != nil {
			return "", fmt.Errorf("failed to marshal services json: %w", err)
		}

		service := fmt.Sprintf("%s-%s", name, key)
		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"create-user-provided-service", service, "-p", string(content)},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to create-user-provided-service: %w\n\nOutput:\n%s", err, log)
		}

		err = s.cli.Execute(pexec.Execution{
			Args:   []string{"bind-service", name, service},
			Stdout: log,
			Stderr: log,
			Env:    env,
		})
		if err != nil {
			return "", fmt.Errorf("failed to bind-service: %w\n\nOutput:\n%s", err, log)
		}
	}

	return fmt.Sprintf("http://tcp.%s:%d", domain, port), nil
}

type SecurityGroupRule struct {
	Destination string `json:"destination"`
	Protocol    string `json:"protocol"`
	Ports       string `json:"ports,omitempty"`
}

var (
	PublicSecurityGroup = []SecurityGroupRule{
		{
			Destination: "0.0.0.0-9.255.255.255",
			Protocol:    "all",
		},
		{
			Destination: "11.0.0.0-169.253.255.255",
			Protocol:    "all",
		},
		{
			Destination: "169.255.0.0-172.15.255.255",
			Protocol:    "all",
		},
		{
			Destination: "172.32.0.0-192.167.255.255",
			Protocol:    "all",
		},
		{
			Destination: "192.169.0.0-255.255.255.255",
			Protocol:    "all",
		},
	}

	PrivateSecurityGroup = []SecurityGroupRule{
		{
			Protocol:    "tcp",
			Destination: "10.0.0.0-10.255.255.255",
			Ports:       "443",
		},
		{
			Protocol:    "tcp",
			Destination: "172.16.0.0-172.31.255.255",
			Ports:       "443",
		},
		{
			Protocol:    "tcp",
			Destination: "192.168.0.0-192.168.255.255",
			Ports:       "443",
		},
	}
)
