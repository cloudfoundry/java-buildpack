package frameworks

import (
	"reflect"
	"strings"
	"testing"
)

// TestShellSplit tests the shellSplit function for various quote scenarios
func TestShellSplit(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []string
		wantErr  bool
	}{
		{
			name:     "simple space-separated",
			input:    "-Xmx512M -Xms256M",
			expected: []string{"-Xmx512M", "-Xms256M"},
			wantErr:  false,
		},
		{
			name:     "single quoted with spaces",
			input:    "-DtestJBPConfig1='test test'",
			expected: []string{"-DtestJBPConfig1=test test"},
			wantErr:  false,
		},
		{
			name:     "double quoted with spaces",
			input:    `-DtestJBPConfig2="test test"`,
			expected: []string{"-DtestJBPConfig2=test test"},
			wantErr:  false,
		},
		{
			name:     "double quoted with env var",
			input:    `-DtestJBPConfig2="$PATH"`,
			expected: []string{"-DtestJBPConfig2=$PATH"},
			wantErr:  false,
		},
		{
			name:     "mixed quotes and plain",
			input:    `-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH" -Xmx512M`,
			expected: []string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH", "-Xmx512M"},
			wantErr:  false,
		},
		{
			name:     "empty string",
			input:    "",
			expected: nil,
			wantErr:  false,
		},
		{
			name:     "only spaces",
			input:    "   ",
			expected: nil,
			wantErr:  false,
		},
		{
			name:     "escaped quotes",
			input:    `test\ with\ spaces`,
			expected: []string{"test with spaces"},
			wantErr:  false,
		},
		{
			name:     "unclosed single quote",
			input:    "-Dtest='unclosed",
			expected: nil,
			wantErr:  true,
		},
		{
			name:     "unclosed double quote",
			input:    `-Dtest="unclosed`,
			expected: nil,
			wantErr:  true,
		},
		{
			name:     "multiple spaces between args",
			input:    "-Xmx512M    -Xms256M",
			expected: []string{"-Xmx512M", "-Xms256M"},
			wantErr:  false,
		},
		{
			name:     "Ruby buildpack example with double single quotes",
			input:    "-DtestJBPConfig1='test test' -DtestJBPConfig2=\"$PATH\"",
			expected: []string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH"},
			wantErr:  false,
		},
		{
			name:     "empty single quotes",
			input:    "-Dtest=''",
			expected: []string{"-Dtest="},
			wantErr:  false,
		},
		{
			name:     "empty double quotes",
			input:    `-Dtest=""`,
			expected: []string{"-Dtest="},
			wantErr:  false,
		},
		{
			name:     "mixed quote types nested (single inside unquoted)",
			input:    "arg1='value with spaces' arg2=plain",
			expected: []string{"arg1=value with spaces", "arg2=plain"},
			wantErr:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := shellSplit(tt.input)

			if tt.wantErr {
				if err == nil {
					t.Errorf("shellSplit() expected error but got none")
				}
				return
			}

			if err != nil {
				t.Errorf("shellSplit() unexpected error: %v", err)
				return
			}

			if !reflect.DeepEqual(result, tt.expected) {
				t.Errorf("shellSplit() = %v, expected %v", result, tt.expected)
			}
		})
	}
}

// TestShellSplitEdgeCases tests additional edge cases
func TestShellSplitEdgeCases(t *testing.T) {
	// Test case from user's issue
	input := `-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH"`
	result, err := shellSplit(input)
	if err != nil {
		t.Fatalf("shellSplit() unexpected error: %v", err)
	}

	expected := []string{"-DtestJBPConfig1=test test", "-DtestJBPConfig2=$PATH"}
	if !reflect.DeepEqual(result, expected) {
		t.Errorf("User's example failed: got %v, expected %v", result, expected)
	}

	// Verify that environment variable is preserved (not expanded)
	if result[1] != "-DtestJBPConfig2=$PATH" {
		t.Errorf("Environment variable should be preserved as literal $PATH, got: %s", result[1])
	}
}

// TestRubyStyleEscape tests the Ruby buildpack-style escaping
func TestRubyStyleEscape(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "simple value no special chars",
			input:    "-Xmx512M",
			expected: "-Xmx512M",
		},
		{
			name:     "value with spaces",
			input:    "-DtestJBPConfig1=test test",
			expected: "-DtestJBPConfig1=test\\ test",
		},
		{
			name:     "value with equals sign (SHOULD be escaped in value!)",
			input:    "-Dkey=value",
			expected: "-Dkey=value",
		},
		{
			name:     "value with equals sign in value part",
			input:    "-Dkey=value=something",
			expected: "-Dkey=value\\=something", // = in VALUE gets escaped!
		},
		{
			name:     "no equals sign",
			input:    "-Xmx512M",
			expected: "-Xmx512M",
		},
		{
			name:     "value with dollar sign (preserved)",
			input:    "-Dpath=$PATH",
			expected: "-Dpath=$PATH",
		},
		{
			name:     "complex value with multiple spaces",
			input:    "-Dprop=hello world test",
			expected: "-Dprop=hello\\ world\\ test",
		},
		{
			name:     "path with slashes (preserved)",
			input:    "/usr/local/bin:/usr/bin",
			expected: "/usr/local/bin:/usr/bin",
		},
		{
			name:     "parentheses in value (original bug!)",
			input:    "-Dtest=(value)",
			expected: "-Dtest=\\(value\\)",
		},
		{
			name:     "percent sign in value",
			input:    "-XX:OnOutOfMemoryError=kill -9 %p",
			expected: "-XX:OnOutOfMemoryError=kill\\ -9\\ \\%p",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := rubyStyleEscape(tt.input)
			if result != tt.expected {
				t.Errorf("rubyStyleEscape() = %q, expected %q", result, tt.expected)
			}
		})
	}
}

// TestShellSplitAndJoin tests the round-trip: parse quoted string, join, and verify format
func TestShellSplitAndJoin(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "simple values",
			input:    "-Xmx512M -Xms256M",
			expected: "-Xmx512M -Xms256M",
		},
		{
			name:     "values with spaces in quotes",
			input:    `-DtestJBPConfig1='test test' -DtestJBPConfig2="value with spaces"`,
			expected: "-DtestJBPConfig1=test test -DtestJBPConfig2=value with spaces",
		},
		{
			name:     "user's example from issue",
			input:    `-DtestJBPConfig1='test test' -DtestJBPConfig2="$PATH"`,
			expected: "-DtestJBPConfig1=test test -DtestJBPConfig2=$PATH",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tokens, err := shellSplit(tt.input)
			if err != nil {
				t.Fatalf("shellSplit() unexpected error: %v", err)
			}

			result := strings.Join(tokens, " ")
			if result != tt.expected {
				t.Errorf("shellSplit + join = %q, expected %q", result, tt.expected)
			}
		})
	}
}
