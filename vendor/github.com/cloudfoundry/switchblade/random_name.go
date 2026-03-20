package switchblade

import (
	"fmt"
	"strings"

	"github.com/teris-io/shortid"
)

func RandomName() (string, error) {
	id, err := shortid.Generate()
	if err != nil {
		return "", err
	}

	// Replace underscores with hyphens to make the name DNS-safe
	// Cloud Foundry uses app names in DNS URLs where underscores are not allowed
	id = strings.ReplaceAll(id, "_", "-")

	return strings.ToLower(fmt.Sprintf("switchblade-%s", id)), nil
}
