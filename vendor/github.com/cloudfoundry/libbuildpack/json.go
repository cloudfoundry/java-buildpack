package libbuildpack

import (
	"bytes"
	"encoding/json"
	"io/ioutil"
)

type JSON struct {
}

func NewJSON() *JSON {
	return &JSON{}
}

const (
	bom0 = 0xef
	bom1 = 0xbb
	bom2 = 0xbf
)

func removeBOM(b []byte) []byte {
	if len(b) >= 3 &&
		b[0] == bom0 &&
		b[1] == bom1 &&
		b[2] == bom2 {
		return b[3:]
	}
	return b
}

func (j *JSON) Load(file string, obj interface{}) error {
	data, err := ioutil.ReadFile(file)
	if err != nil {
		return err
	}

	err = json.Unmarshal(removeBOM(data), obj)
	if err != nil {
		return err
	}

	return nil
}

func (j *JSON) Write(dest string, obj interface{}) error {
	data, err := json.Marshal(&obj)
	if err != nil {
		return err
	}

	err = writeToFile(bytes.NewBuffer(data), dest, 0666)
	if err != nil {
		return err
	}
	return nil
}
