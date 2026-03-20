package docker

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httputil"
	"strings"
	"sync"
)

var DefaultBuildpacks = []string{
	"staticfile",
	"java",
	"ruby",
	"dotnet-core",
	"nodejs",
	"go",
	"python",
	"php",
	"nginx",
	"r",
	"binary",
}

type BuildpacksRegistry struct {
	api   string
	token string
	index *sync.Map
}

func NewBuildpacksRegistry(api, token string) BuildpacksRegistry {
	return BuildpacksRegistry{
		api:   api,
		token: token,
		index: &sync.Map{},
	}
}

func (r BuildpacksRegistry) List() ([]Buildpack, error) {
	var list []Buildpack
	for _, name := range DefaultBuildpacks {
		name = fmt.Sprintf("%s-buildpack", name)
		buildpack := Buildpack{Name: strings.ReplaceAll(name, "-", "_")}

		value, ok := r.index.Load(buildpack.Name)
		if ok {
			buildpack.URI = value.(string)
		} else {
			req, err := http.NewRequest("GET", fmt.Sprintf("%s/repos/cloudfoundry/%s/releases/latest", r.api, name), nil)
			if err != nil {
				return nil, fmt.Errorf("failed to create request: %w", err)
			}

			req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", r.token))

			resp, err := http.DefaultClient.Do(req)
			if err != nil {
				return nil, fmt.Errorf("failed to complete request: %w", err)
			}

			if resp.StatusCode != http.StatusOK {
				dump, _ := httputil.DumpResponse(resp, true)
				return nil, fmt.Errorf("received unexpected response status: %s", dump)
			}

			var release struct {
				Assets []struct {
					Name               string `json:"name"`
					BrowserDownloadURL string `json:"browser_download_url"`
				} `json:"assets"`
			}
			err = json.NewDecoder(resp.Body).Decode(&release)
			if err != nil {
				return nil, fmt.Errorf("failed to parse response json: %w", err)
			}

			for _, asset := range release.Assets {
				if strings.HasSuffix(asset.Name, ".zip") {
					buildpack.URI = asset.BrowserDownloadURL
					break
				}
			}

			r.index.Store(buildpack.Name, buildpack.URI)
		}

		list = append(list, buildpack)
	}

	r.index.Range(func(key, value interface{}) bool {
		name := key.(string)
		for _, buildpack := range DefaultBuildpacks {
			if name == strings.ReplaceAll(fmt.Sprintf("%s-buildpack", buildpack), "-", "_") {
				return true
			}
		}

		list = append(list, Buildpack{
			Name: name,
			URI:  value.(string),
		})

		return true
	})

	return list, nil
}

func (r BuildpacksRegistry) Override(buildpacks ...Buildpack) {
	for _, buildpack := range buildpacks {
		r.index.Store(buildpack.Name, buildpack.URI)
	}
}
