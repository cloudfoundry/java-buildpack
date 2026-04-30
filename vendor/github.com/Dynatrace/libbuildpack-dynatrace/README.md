# libbuildpack-dynatrace

Base Library for Go-based Cloud Foundry Buildpack integrations with Dynatrace.

## Summary

The library provides the `Hook` struct that implements the `libbuildpack.Hook` interface that it's requested by the CF Buildpacks.

On the buildpacks, you're expected to provide a hook through a `init()` function where you can register such hook implementation. For example, a simple implementation could be,

```go
import (
	"github.com/cloudfoundry/libbuildpack"
	"github.com/Dynatrace/libbuildpack-dynatrace"
)

func init() {
	libbuildpack.AddHook(dynatrace.NewHook("nodejs", "process"))
}
```

## Configuration

The Hook will look for credentials in the configurations for existing services. It searches for service credentials depending on the binding type:

1. **File-based**: If the `VCAP_SERVICES_FILE_PATH` environment variable is set, the hook reads the VCAP_SERVICES JSON from the file at that path.
2. **Environment variable**: If the env var `VCAP_SERVICES` is set, it reads the JSON from the `VCAP_SERVICES` environment variable directly.

In both cases, we look for service names having the 'dynatrace' substring.

We support the following configuration fields,

| Key           | Type    | Description                                                                                 | Required | Default         |
| ------------- | ------- | ------------------------------------------------------------------------------------------- | -------- | --------------- |
| environmentid | string  | The ID for the Dynatrace environment.                                                       | Yes      | N/A             |
| apitoken      | string  | The API Token for the Dynatrace environment.                                                | Yes      | N/A             |
| apiurl        | string  | Overrides the default Dynatrace API URL to connect to.                                      | No       | Default API URL |
| skiperrors    | boolean | If true, the deployment doesn't fail if the Dynatrace agent download fails.                 | No       | false           |
| networkzone   | string  | If set, agent is configured to choose communication endpoints located at the field's value. | No       | empty           |
| enablefips    | boolean | If true, the [FIPS 140-2 mode](https://www.dynatrace.com/news/blog/dynatrace-achieves-fips-140-2-certification/) is enabled | No       | false           |
| addtechnologies| string | Adds additional OneAgent code-modules via a comma-separated list. See [supported values](https://docs.dynatrace.com/docs/dynatrace-api/environment-api/deployment/oneagent/download-oneagent-version#parameters) in the "included" row | No | empty |

For example,

```bash
cf create-user-provided-service dynatrace -p '{"environmentid":"...","apitoken":"..."}'
```

See more at the documentation for [`cf create-user-provided-service`](http://cli.cloudfoundry.org/en-US/cf/create-user-provided-service.html).

We also support standard Dynatrace environment variables.

## Requirements

- Go 1.19 or higher.
- Deployment targets: Linux and Windows.
- Development and testing: Linux, Mac OS, and Windows.

## Development

You can download or clone the repository.

You can run tests through,

```
go test ./...
```

By default, tests simulate the Linux platform. To test against a different target OS, use the `-os` flag:

```
go test ./... -os=windows
go test ./... -os=linux
```

If you modify/add interfaces, you may need to regenerate the mocks. For this you need [gomock](https://github.com/golang/mock):

```
# To download Gomock
go get github.com/golang/mock/gomock
go install github.com/golang/mock/mockgen

# To generate the mocks
go generate
```
