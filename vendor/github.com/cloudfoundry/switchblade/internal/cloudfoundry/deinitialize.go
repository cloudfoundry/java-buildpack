package cloudfoundry

// This is noop functionality for the time being to reflect the docker structure

type DeinitializePhase interface {
	Run() error
}

type Deinitialize struct{}

func NewDeinitialize() Deinitialize {
	return Deinitialize{}
}

func (d Deinitialize) Run() error {
	return nil
}
