package containers

import (
	"github.com/cloudfoundry/java-buildpack/src/java/common"
)

// Container represents a Java application container (Tomcat, Spring Boot, etc.)
type Container interface {
	// Detect returns true if this container should handle the application
	// Returns the container name and version if detected
	Detect() (string, error)

	// Supply installs the container and its dependencies
	Supply() error

	// Finalize performs final container configuration
	Finalize() error

	// Release returns the startup command for the container
	Release() (string, error)
}


// Registry manages available containers
type Registry struct {
	containers []Container
	context    *common.Context
}

// NewRegistry creates a new container registry
func NewRegistry(ctx *common.Context) *Registry {
	return &Registry{
		containers: []Container{},
		context:    ctx,
	}
}

// Register adds a container to the registry
func (r *Registry) Register(c Container) {
	r.containers = append(r.containers, c)
}

// Detect finds the first container that can handle the application
func (r *Registry) Detect() (Container, string, error) {
	for _, container := range r.containers {
		name, err := container.Detect()
		if err != nil {
			// Propagate errors (e.g., validation failures)
			return nil, "", err
		}
		if name != "" {
			return container, name, nil
		}
	}
	return nil, "", nil
}

// DetectAll returns all containers that can handle the application
func (r *Registry) DetectAll() ([]Container, []string, error) {
	var matched []Container
	var names []string

	for _, container := range r.containers {
		name, err := container.Detect()
		if err != nil {
			// Propagate errors (e.g., validation failures)
			return nil, nil, err
		}
		if name != "" {
			matched = append(matched, container)
			names = append(names, name)
		}
	}

	return matched, names, nil
}

// RegisterStandardContainers registers all standard containers in the correct priority order.
// This ensures Supply and Finalize phases use the same detection order.
// IMPORTANT: The order matters! Containers are checked in registration order.
// More specific containers (with stricter detection rules) must come before generic ones.
func (r *Registry) RegisterStandardContainers() {
	// Priority order (most specific to least specific):
	// 1. Spring Boot - checks for BOOT-INF or Spring Boot JAR markers
	// 2. Spring Boot CLI - checks for Groovy files with POGO/beans patterns (NO main method, NO shebang)
	// 3. Tomcat - checks for WEB-INF or WAR files
	// 4. Groovy - checks for Groovy files (with main method OR shebang)
	// 5. Play - checks for Play Framework structure
	// 6. DistZip - checks for bin/ and lib/ directories
	// 7. JavaMain - checks for executable JAR with Main-Class manifest entry
	r.Register(NewSpringBootContainer(r.context))
	r.Register(NewSpringBootCLIContainer(r.context))
	r.Register(NewTomcatContainer(r.context))
	r.Register(NewGroovyContainer(r.context))
	r.Register(NewPlayContainer(r.context))
	r.Register(NewDistZipContainer(r.context))
	r.Register(NewJavaMainContainer(r.context))
}
