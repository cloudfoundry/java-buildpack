module github.com/cloudfoundry/java-buildpack

go 1.25.4

require (
	github.com/Dynatrace/libbuildpack-dynatrace v1.9.0
	github.com/cloudfoundry/libbuildpack v0.0.0-20261012122722-6cd465089938
	github.com/golang/mock v1.6.0
	github.com/onsi/ginkgo/v2 v2.29.0
	github.com/onsi/gomega v1.42.0
	go.yaml.in/yaml/v3 v3.0.4
	gopkg.in/yaml.v2 v2.4.0
)

require (
	github.com/Masterminds/semver v1.5.0 // indirect
	github.com/Masterminds/semver/v3 v3.4.0 // indirect
	github.com/blang/semver v3.5.1+incompatible // indirect
	github.com/cenkalti/backoff/v4 v4.3.0 // indirect
	github.com/fsnotify/fsnotify v1.8.0 // indirect
	github.com/go-logr/logr v1.4.3 // indirect
	github.com/go-task/slim-sprig/v3 v3.0.0 // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/google/pprof v0.0.0-20260402051712-545e8a4df936 // indirect
	github.com/rogpeppe/go-internal v1.14.1 // indirect
	github.com/stretchr/testify v1.11.1 // indirect
	golang.org/x/mod v0.35.0 // indirect
	golang.org/x/net v0.55.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.45.0 // indirect
	golang.org/x/text v0.37.0 // indirect
	golang.org/x/tools v0.44.0 // indirect
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
)

// Replace directives to fix OpenTelemetry dependency conflicts from docker/docker test dependencies
// The docker client's test code (which we don't run) pulls in old OTEL versions with reorganized internals
