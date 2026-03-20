package common

import (
	"bytes"
	"go.yaml.in/yaml/v3"
)

// YamlHandler provides a thin wrapper around yaml.v3's Marshal and Unmarshal.
type YamlHandler struct{}

// Unmarshal decodes the YAML data into the provided destination.
func (h YamlHandler) Unmarshal(data []byte, out any) error {
	return yaml.Unmarshal(data, out)
}

// Marshal encodes the given value into YAML.
func (h YamlHandler) Marshal(in any) ([]byte, error) {
	return yaml.Marshal(in)
}

// ValidateFields is used to detect unknown fields during parsing of JBP_CONFIG* configurations
func (h YamlHandler) ValidateFields(data []byte, out interface{}) error {
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	return dec.Decode(out)
}
