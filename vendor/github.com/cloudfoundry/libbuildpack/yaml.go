package libbuildpack

import (
	"bytes"
	"io/ioutil"

	yaml "gopkg.in/yaml.v2"
)

type YAML struct {
}

func NewYAML() *YAML {
	return &YAML{}
}

func (y *YAML) Load(file string, obj interface{}) error {
	data, err := ioutil.ReadFile(file)
	if err != nil {
		return err
	}

	err = yaml.Unmarshal(data, obj)
	if err != nil {
		return err
	}

	return nil
}

func (y *YAML) Write(dest string, obj interface{}) error {
	data, err := yaml.Marshal(&obj)
	if err != nil {
		return err
	}

	err = writeToFile(bytes.NewBuffer(data), dest, 0666)
	if err != nil {
		return err
	}
	return nil
}
