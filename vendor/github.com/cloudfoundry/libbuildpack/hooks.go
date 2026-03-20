package libbuildpack

import (
	"sync"
)

type Hook interface {
	BeforeCompile(*Stager) error
	AfterCompile(*Stager) error
}

var hookArray []Hook
var hookArrayLock sync.Mutex

func AddHook(hook Hook) {
	hookArrayLock.Lock()
	hookArray = append(hookArray, hook)
	hookArrayLock.Unlock()
}
func ClearHooks() {
	hookArrayLock.Lock()
	hookArray = make([]Hook, 0)
	hookArrayLock.Unlock()
}

func RunBeforeCompile(stager *Stager) error {
	for _, hook := range hookArray {
		if err := hook.BeforeCompile(stager); err != nil {
			return err
		}
	}
	return nil
}

func RunAfterCompile(stager *Stager) error {
	for _, hook := range hookArray {
		if err := hook.AfterCompile(stager); err != nil {
			return err
		}
	}
	return nil
}

type DefaultHook struct{}

func (d DefaultHook) BeforeCompile(stager *Stager) error { return nil }
func (d DefaultHook) AfterCompile(stager *Stager) error  { return nil }
