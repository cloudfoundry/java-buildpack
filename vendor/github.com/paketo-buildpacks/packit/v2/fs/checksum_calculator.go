package fs

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sort"
)

// ChecksumCalculator can be used to calculate the SHA256 checksum of a given file or
// directory. When given a directory, checksum calculation will be performed in
// parallel.
type ChecksumCalculator struct{}

// NewChecksumCalculator returns a new instance of a ChecksumCalculator.
func NewChecksumCalculator() ChecksumCalculator {
	return ChecksumCalculator{}
}

type calculatedFile struct {
	path     string
	checksum []byte
	err      error
}

// Sum returns a hex-encoded SHA256 checksum value of a file or directory given a path.
func (c ChecksumCalculator) Sum(paths ...string) (string, error) {
	var files []string
	for _, path := range paths {
		err := filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			if info.Mode().IsRegular() {
				files = append(files, path)
			}

			return nil
		})
		if err != nil {
			return "", fmt.Errorf("failed to calculate checksum: %w", err)
		}
	}

	//Gather all checksums
	var sums [][]byte
	for _, f := range getParallelChecksums(files) {
		if f.err != nil {
			return "", fmt.Errorf("failed to calculate checksum: %w", f.err)
		}

		sums = append(sums, f.checksum)
	}

	if len(sums) == 1 {
		return hex.EncodeToString(sums[0]), nil
	}

	hash := sha256.New()
	for _, sum := range sums {
		_, err := hash.Write(sum)
		if err != nil {
			return "", fmt.Errorf("failed to calculate checksum: %w", err)
		}
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func getParallelChecksums(filesFromDir []string) []calculatedFile {
	var checksumResults []calculatedFile
	numFiles := len(filesFromDir)
	files := make(chan string, numFiles)
	calculatedFiles := make(chan calculatedFile, numFiles)

	//Spawns workers
	for i := 0; i < runtime.NumCPU(); i++ {
		go fileChecksumer(files, calculatedFiles)
	}

	//Puts files in worker queue
	for _, f := range filesFromDir {
		files <- f
	}

	close(files)

	//Pull all calculated files off of result queue
	for i := 0; i < numFiles; i++ {
		checksumResults = append(checksumResults, <-calculatedFiles)
	}

	//Sort calculated files for consistent checksuming
	sort.Slice(checksumResults, func(i, j int) bool {
		return checksumResults[i].path < checksumResults[j].path
	})

	return checksumResults
}

func fileChecksumer(files chan string, calculatedFiles chan calculatedFile) {
	for path := range files {
		result := calculatedFile{path: path}

		file, err := os.Open(path)
		if err != nil {
			result.err = err
			calculatedFiles <- result
			continue
		}

		hash := sha256.New()
		_, err = io.Copy(hash, file)
		if err != nil {
			result.err = err
			calculatedFiles <- result
			continue
		}

		if err := file.Close(); err != nil {
			result.err = err
			calculatedFiles <- result
			continue
		}

		result.checksum = hash.Sum(nil)
		calculatedFiles <- result
	}
}
