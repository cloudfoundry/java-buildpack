package matchers

import (
	"fmt"
	"reflect"
	"regexp"
	"strings"

	"github.com/onsi/gomega/format"
	"github.com/onsi/gomega/types"
)

func ContainLines(expected ...interface{}) types.GomegaMatcher {
	return &containLinesMatcher{
		expected: expected,
	}
}

type containLinesMatcher struct {
	expected []interface{}
}

func (matcher *containLinesMatcher) Match(actual interface{}) (success bool, err error) {
	_, ok := actual.(string)
	if !ok {
		_, ok := actual.(fmt.Stringer)
		if !ok {
			return false, fmt.Errorf("ContainLinesMatcher requires a string or fmt.Stringer. Got actual: %s", format.Object(actual, 1))
		}
	}

	actualLines := matcher.lines(actual)

	for currentActualLineIndex := 0; currentActualLineIndex < len(actualLines); currentActualLineIndex++ {
		currentActualLine := actualLines[currentActualLineIndex]
		currentExpectedLine := matcher.expected[currentActualLineIndex]

		match, err := matcher.compare(currentActualLine, currentExpectedLine)
		if err != nil {
			return false, err
		}

		if match {
			if currentActualLineIndex+1 == len(matcher.expected) {
				return true, nil
			}
		} else {
			if len(actualLines) > 1 {
				actualLines = actualLines[1:]
				currentActualLineIndex = -1
			}
		}
	}

	return false, nil
}

func (matcher *containLinesMatcher) compare(actual string, expected interface{}) (bool, error) {
	if m, ok := expected.(types.GomegaMatcher); ok {
		match, err := m.Match(actual)
		if err != nil {
			return false, err
		}

		return match, nil
	}

	return reflect.DeepEqual(actual, expected), nil
}

func (matcher *containLinesMatcher) lines(actual interface{}) []string {
	raw, ok := actual.(string)
	if !ok {
		raw = actual.(fmt.Stringer).String()
	}

	re := regexp.MustCompile(`^\[[a-z]+\]\s`)

	var lines []string
	for _, line := range strings.Split(raw, "\n") {
		lines = append(lines, re.ReplaceAllString(line, ""))
	}

	return lines
}

func (matcher *containLinesMatcher) FailureMessage(actual interface{}) (message string) {
	actualLines := "\n" + strings.Join(matcher.lines(actual), "\n")
	missing := matcher.linesMatching(actual, false)
	if len(missing) > 0 {
		return fmt.Sprintf("Expected\n%s\nto contain lines\n%s\nbut missing\n%s", format.Object(actualLines, 1), format.Object(matcher.expected, 1), format.Object(missing, 1))
	}

	return fmt.Sprintf("Expected\n%s\nto contain lines\n%s\nall lines appear, but may be misordered", format.Object(actualLines, 1), format.Object(matcher.expected, 1))
}

func (matcher *containLinesMatcher) NegatedFailureMessage(actual interface{}) (message string) {
	actualLines := "\n" + strings.Join(matcher.lines(actual), "\n")
	missing := matcher.linesMatching(actual, true)

	return fmt.Sprintf("Expected\n%s\nnot to contain lines\n%s\nbut includes\n%s", format.Object(actualLines, 1), format.Object(matcher.expected, 1), format.Object(missing, 1))
}

func (matcher *containLinesMatcher) linesMatching(actual interface{}, matching bool) []interface{} {
	var set []interface{}
	for _, expected := range matcher.expected {
		var match bool
		for _, line := range matcher.lines(actual) {
			if ok, _ := matcher.compare(line, expected); ok {
				match = true
			}
		}

		if match == matching {
			set = append(set, expected)
		}
	}

	return set
}
