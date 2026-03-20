_Have something you'd like to contribute to the buildpack? We welcome pull requests, but ask that you carefully read this document first to understand how best to submit them; what kind of changes are likely to be accepted; and what to expect from the Cloud Foundry Java Experience team when evaluating your submission._

_Please refer back to this document as a checklist before issuing any pull request; this will save time for everyone!_

## Understanding the basics
Not sure what a pull request is, or how to submit one?  Take a look at GitHub's excellent [help documentation][] first.

[help documentation]: http://help.github.com/send-pull-requests

## Search GitHub Issues first; create an issue if necessary
Is there already an issue that addresses your concern?  Do a bit of searching in our [GitHub issue tracker][] to see if you can find something similar. If not, please create a new issue before submitting a pull request unless the change is truly trivial, e.g. typo fixes, removing compiler warnings, etc.

[GitHub issue tracker]: https://github.com/cloudfoundry/java-buildpack/issues

## Discuss non-trivial contribution ideas with committers

If you're considering anything more than correcting a typo or fixing a minor bug, please discuss it on the [vcap-dev][] mailing list before submitting a pull request. We're happy to provide guidance, but please spend an hour or two researching the subject on your own including searching the mailing list for prior discussions.

[vcap-dev]: https://groups.google.com/a/cloudfoundry.org/forum/#!forum/vcap-dev

## Sign the Contributor License Agreement
If you are not yet covered under a Corporate CLA or Individual CLA, you'll be prompted to sign or be approved by your company when you put in your first Pull Request. Please follow the prompts in the EasyCLA check within that Pull Request. For additional assistance please [open a ticket here][].

[open a ticket here]: https://jira.linuxfoundation.org/servicedesk/customer/portal/4

## Use short branch names
Branches used when submitting pull requests should preferably using succinct, lower-case, dash (-) delimited names, such as 'fix-warnings', 'fix-typo', etc. In [fork-and-edit][] cases, the GitHub default 'patch-1' is fine as well. This is important, because branch names show up in the merge commits that result from accepting pull requests, and should be as expressive and concise as possible.

[fork-and-edit]: https://github.com/blog/844-forking-with-the-edit-button

## Follow Go Code Standards

This buildpack is implemented in Go. Please follow Go conventions and best practices:

### Formatting

1. **Use `gofmt`** - All Go code must be formatted with `gofmt` before submission
   ```bash
   gofmt -w src/java/
   ```
1. **Use `goimports`** - Organize imports properly
   ```bash
   go install golang.org/x/tools/cmd/goimports@latest
   goimports -w src/java/
   ```
1. **Tabs for indentation** - Go standard (gofmt will handle this)
1. **Unix (LF) line endings** - Not DOS (CRLF)
1. **Eliminate trailing whitespace**
1. **Line length** - Aim for 120 characters, but favor readability
1. **Preserve existing formatting** - Do not reformat code for its own sake

### Naming Conventions

1. **Exported names** - Start with capital letter (e.g., `NewFramework`, `Detect`)
1. **Unexported names** - Start with lowercase letter (e.g., `parseConfig`, `isEnabled`)
1. **Acronyms** - Use all caps (e.g., `HTTP`, `URL`, `JRE`, `JVM`)
1. **Interface names** - Single method interfaces end in "-er" (e.g., `Reader`, `Writer`)
1. **File names** - Use snake_case (e.g., `new_relic_agent.go`, `spring_boot.go`)
1. **Test files** - Name with `_test.go` suffix (e.g., `new_relic_agent_test.go`)

### Code Quality

1. **Run `go vet`** - Check for common mistakes
   ```bash
   go vet ./src/java/...
   ```
1. **Run `golint`** - Check for style issues (optional but recommended)
   ```bash
   go install golang.org/x/lint/golint@latest
   golint ./src/java/...
   ```
1. **Error handling** - Always check errors; wrap with context using `fmt.Errorf`
   ```go
   if err != nil {
       return fmt.Errorf("failed to install framework: %w", err)
   }
   ```
1. **Comments** - Use complete sentences; start with the name being documented
   ```go
   // NewFramework creates a new framework instance.
   // The context provides access to buildpack services.
   func NewFramework(ctx *Context) *Framework {
   ```

### UTF-8 Encoding

Use UTF-8 encoding for all source files (Go standard)

## Add Apache license header to all new Go files

```go
// Cloud Foundry Java Buildpack
// Copyright 2013-2025 the original author or authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package frameworks

import (
    "fmt"
    // ...
)
```

## Update Apache license header to modified files as necessary

Always check the date range in the license header. For example, if you've modified a file in 2020 whose header still reads:

```go
 // Copyright 2013-2020 the original author or authors.
```

then be sure to update it to 2025 appropriately:

```go
 // Copyright 2013-2025 the original author or authors.
```

## Submit test cases for all behavior changes

### Unit Tests

All new features and bug fixes must include unit tests. The buildpack uses:
- **Standard Go testing** for simple tests
- **Ginkgo v2** for BDD-style tests
- **Gomega** for assertions

Search the codebase to find related unit tests and add additional test specs within.

**Example test structure:**

```go
package frameworks_test

import (
    "testing"
    "github.com/cloudfoundry/java-buildpack/src/java/frameworks"
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

func TestFrameworks(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Frameworks Suite")
}

var _ = Describe("MyFramework", func() {
    Context("when service is bound", func() {
        It("detects the framework", func() {
            // Test logic
            Expect(result).To(Equal("my-framework"))
        })
    })
})
```

### Running Tests

Before submitting your pull request:

```bash
# Run unit tests
./scripts/unit.sh

# Run specific package tests
cd src/java
ginkgo frameworks/

# Check code formatting
gofmt -d src/java/

# Check for common issues
go vet ./src/java/...
```

### Test Requirements

1. **Unit tests are required** for all new code
2. **Integration tests** should be added for new containers or significant framework changes
3. **Test coverage** should not decrease - aim for >85% coverage
4. **All tests must pass** before submission

See [docs/TESTING.md](docs/TESTING.md) for comprehensive testing guidelines.

## Squash commits
Use `git rebase --interactive`, `git add --patch` and other tools to "squash"multiple commits into atomic changes. In addition to the man pages for git, there are many resources online to help you understand how these tools work. Here is one: <http://book.git-scm.com/4_interactive_rebasing.html>.

## Use real name in git commits
Please configure git to use your real first and last name for any commits you intend to submit as pull requests. For example, this is not acceptable:

```plain
Author: Nickname <user@mail.com>
```

Rather, please include your first and last name, properly capitalized, as submitted against the Pivotal contributor license agreement:

```plain
Author: First Last <user@mail.com>
```

This helps ensure traceability against the CLA, and also goes a long way to ensuring useful output from tools like `git shortlog` and others.

You can configure this globally via the account admin area GitHub (useful for fork-and-edit cases); globally with

```bash
git config --global user.name "First Last"
git config --global user.email user@mail.com
```

or locally for the `java-buildpack` repository only by omitting the `--global` flag:

```bash
cd java-buildpack
git config user.name "First Last"
git config user.email user@mail.com
```

## Format commit messages
Please read and follow the [commit guidelines section of Pro Git][].

Most importantly, please format your commit messages in the following way (adapted from the commit template in the link above):

```plain
Short (50 chars or less) summary of changes

More detailed explanatory text, if necessary. Wrap it to about 72
characters or so. In some contexts, the first line is treated as the
subject of an email and the rest of the text as the body. The blank
line separating the summary from the body is critical (unless you omit
the body entirely); tools like rebase can get confused if you run the
two together.

Further paragraphs come after blank lines.

 - Bullet points are okay, too

 - Typically a hyphen or asterisk is used for the bullet, preceded by a
   single space, with blank lines in between, but conventions vary here

Issue: #10, #11
```

1. Use imperative statements in the subject line, e.g. "Fix broken documentation link"
1. Begin the subject line sentence with a capitalized verb, e.g. "Add, Prune, Fix, Introduce, Avoid, etc."
1. Do not end the subject line with a period
1. Keep the subject line to 50 characters or less if possible
1. Wrap lines in the body at 72 characters or less
1. Mention associated GitHub issue(s) at the end of the commit comment, prefixed with "Issue: " as above
1. In the body of the commit message, explain how things worked before this commit, what has changed, and how things work now

[commit guidelines section of Pro Git]: http://progit.org/book/ch5-2.html#commit_guidelines

## Run all checks prior to submission

Before submitting your pull request, ensure all checks pass:

### 1. Format Code

```bash
# Format Go code
gofmt -w src/java/

# Organize imports (optional but recommended)
goimports -w src/java/
```

### 2. Run Tests

```bash
# Run all unit tests
./scripts/unit.sh

# Run specific tests
cd src/java
ginkgo frameworks/
ginkgo containers/
```

### 3. Static Analysis

```bash
# Check for common mistakes
go vet ./src/java/...

# Check for style issues (optional)
golint ./src/java/...
```

### 4. Build Buildpack

```bash
# Ensure buildpack compiles
./scripts/build.sh
```

### 5. Integration Tests (for significant changes)

```bash
# Package buildpack
./scripts/package.sh --version dev

# Run integration tests
export BUILDPACK_FILE="${PWD}/build/buildpack.zip"
./scripts/integration.sh --platform docker
```

Make sure that all tests pass and the buildpack builds successfully prior to submitting your pull request.

See [docs/DEVELOPING.md](docs/DEVELOPING.md) for detailed development workflow.

# Submit your pull request
Subject line:

Follow the same conventions for pull request subject lines as mentioned above for commit message subject lines.

In the body:

1. Explain your use case. What led you to submit this change? Why were existing mechanisms in the buildpack insufficient? Make a case that this is a general-purpose problem and that yours is a general-purpose solution, etc.
1. Add any additional information and ask questions; start a conversation, or continue one from GitHub issue
1. Also mention that you have submitted the CLA as described above

Note that for pull requests containing a single commit, GitHub will default the subject line and body of the pull request to match the subject line and body of the commit message. This is fine, but please also include the items above in the body of the request.

## Expect discussion and rework
The Cloud Foundry Java Experience team takes a very conservative approach to accepting contributions to the buildpack. This is to keep code quality and stability as high as possible, and to keep complexity at a minimum. Your changes, if accepted, may be heavily modified prior to merging. You will retain "Author:" attribution for your Git commits granted that the bulk of your changes remain intact. You may be asked to rework the submission for style (as explained above) and/or substance. Again, we strongly recommend discussing any serious submissions with the Cloud Foundry Java Experience team _prior_ to engaging in serious development work.

Note that you can always force push (`git push -f`) reworked / rebased commits against the branch used to submit your pull request. i.e. you do not need to issue a new pull request when asked to make changes.

## Go-Specific Contribution Guidelines

### Project Structure

```
src/java/
├── containers/       # Container implementations (Tomcat, Spring Boot, etc.)
├── frameworks/       # Framework integrations (APM agents, security, etc.)
├── jres/            # JRE providers (OpenJDK, Zulu, GraalVM, etc.)
├── supply/          # Supply phase entrypoint
├── finalize/        # Finalize phase entrypoint
└── integration/     # Integration tests
```

### Implementing New Components

When adding new frameworks, containers, or JREs:

1. **Read the implementation guides:**
   - [Implementing Frameworks](docs/IMPLEMENTING_FRAMEWORKS.md)
   - [Implementing Containers](docs/IMPLEMENTING_CONTAINERS.md)
   - [Implementing JREs](docs/IMPLEMENTING_JRES.md)

2. **Follow the component interface pattern:**
   ```go
   type Component interface {
       Detect() (string, error)  // Returns detection tag
       Supply() error            // Install dependencies
       Finalize() error          // Configure runtime
   }
   ```

3. **Required files:**
   - Implementation: `src/java/{type}/my_component.go`
   - Tests: `src/java/{type}/my_component_test.go`
   - Config: `config/my_component.yml`
   - Documentation: `docs/{type}-my_component.md`
   - Registration: Update `config/components.yml`

### Go Best Practices for This Project

1. **Use context struct for dependencies**
   ```go
   type Context struct {
       Stager    *libbuildpack.Stager
       Manifest  *libbuildpack.Manifest
       Installer *libbuildpack.Installer
       Log       *libbuildpack.Logger
       Command   *libbuildpack.Command
   }
   ```

2. **Error handling with context**
   ```go
   if err != nil {
       return fmt.Errorf("failed to install framework: %w", err)
   }
   ```

3. **Logging at appropriate levels**
   ```go
   ctx.Log.BeginStep("Installing Framework")  // Major steps
   ctx.Log.Info("Installed version %s", ver)  // Important info
   ctx.Log.Warning("Feature disabled")        // Warnings
   ctx.Log.Debug("Config: %+v", config)       // Debug details
   ```

4. **Use filepath.Join for paths**
   ```go
   // GOOD
   path := filepath.Join(baseDir, "subdir", "file.txt")
   
   // BAD
   path := baseDir + "/subdir/file.txt"
   ```

5. **Table-driven tests**
   ```go
   tests := []struct {
       name     string
       input    string
       expected string
   }{
       {"case 1", "input1", "output1"},
       {"case 2", "input2", "output2"},
   }
   
   for _, tt := range tests {
       t.Run(tt.name, func(t *testing.T) {
           // Test logic
       })
   }
   ```

### Common Patterns

- **Service-bound detection**: Parse `VCAP_SERVICES` to find bound services
- **File-based detection**: Check for specific files/directories in build directory
- **Configuration-based**: Read from `JBP_CONFIG_*` environment variables
- **Profile.d scripts**: Write runtime configuration to `.profile.d/` directory
- **Java agents**: Add `-javaagent:path/to/agent.jar` to `JAVA_OPTS`

### Resources for Contributors

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Buildpack architecture overview
- **[docs/DEVELOPING.md](docs/DEVELOPING.md)** - Development workflow and setup
- **[docs/TESTING.md](docs/TESTING.md)** - Testing guidelines and patterns
- **[docs/design.md](docs/design.md)** - High-level design concepts

### Getting Help

- **GitHub Issues**: [java-buildpack/issues](https://github.com/cloudfoundry/java-buildpack/issues)
- **Slack**: [Cloud Foundry Slack](https://slack.cloudfoundry.org) - #buildpacks channel
- **Mailing List**: [cf-dev](https://lists.cloudfoundry.org/g/cf-dev)
