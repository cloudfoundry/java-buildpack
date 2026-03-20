package libbuildpack

import (
	"fmt"
	"io"
	"os"
	"strings"
)

type Logger struct {
	w io.Writer
}

const (
	msgPrefix   = "       "
	redPrefix   = "\033[31;1m"
	bluePrefix  = "\033[34;1m"
	colorSuffix = "\033[0m"
	msgError    = msgPrefix + redPrefix + "**ERROR**" + colorSuffix
	msgWarning  = msgPrefix + redPrefix + "**WARNING**" + colorSuffix
	msgProtip   = msgPrefix + bluePrefix + "PRO TIP:" + colorSuffix
	msgDebug    = msgPrefix + bluePrefix + "DEBUG:" + colorSuffix
)

func NewLogger(w io.Writer) *Logger {
	return &Logger{w: w}
}

func (l *Logger) Info(format string, args ...interface{}) {
	l.printWithHeader("      ", format, args...)
}

func (l *Logger) Warning(format string, args ...interface{}) {
	l.printWithHeader(msgWarning, format, args...)

}
func (l *Logger) Error(format string, args ...interface{}) {
	l.printWithHeader(msgError, format, args...)
}

func (l *Logger) Debug(format string, args ...interface{}) {
	if os.Getenv("BP_DEBUG") != "" {
		l.printWithHeader(msgDebug, format, args...)
	}
}

func (l *Logger) BeginStep(format string, args ...interface{}) {
	l.printWithHeader("----->", format, args...)
}

func (l *Logger) Protip(tip string, helpURL string) {
	l.printWithHeader(msgProtip, "%s", tip)
	l.printWithHeader(msgPrefix+"Visit", "%s", helpURL)
}

func (l *Logger) printWithHeader(header string, format string, args ...interface{}) {
	msg := fmt.Sprintf(format, args...)

	msg = strings.Replace(msg, "\n", "\n       ", -1)
	fmt.Fprintf(l.w, "%s %s\n", header, msg)
}

func (l *Logger) Output() io.Writer {
	return l.w
}
