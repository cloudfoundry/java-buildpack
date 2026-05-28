package javaexec

import (
	"reflect"
	"testing"
)

func TestBuildArgs(t *testing.T) {
	got := BuildArgs("/jdk/bin/java", `-Xmx1g -Dfoo="bar baz"`,
		[]string{"-jar", "app.jar"})
	want := []string{"/jdk/bin/java", "-Xmx1g", "-Dfoo=bar baz", "-jar", "app.jar"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("BuildArgs = %#v, want %#v", got, want)
	}
}

func TestBuildArgsEmptyOptsHasNoEmptyArg(t *testing.T) {
	got := BuildArgs("/jdk/bin/java", "", []string{"-jar", "app.jar"})
	want := []string{"/jdk/bin/java", "-jar", "app.jar"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("BuildArgs with empty JAVA_OPTS = %#v, want %#v", got, want)
	}
}
