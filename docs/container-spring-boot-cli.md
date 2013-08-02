# Spring Boot CLI Container
The Spring Boot CLI Container runs one or more Groovy (i.e. `*.groovy`) files using Spring Boot CLI.

<table>
	<tr>
		<td><strong>Detection Criteria</strong></td><td><ul>
			<li>The application has one or more <tt>.groovy</tt> files in the root directory, and</li>
			<li>All the application's <tt>.groovy</tt> files in the root directory are POGOs (a POGO contains one or more classes), and</li>
			<li>None of the application's <tt>.groovy</tt> files in the root directory contain a <tt>main</tt> method, and</li>
		    <li>The application does not have a <tt>WEB-INF</tt> subdirectory of its root directory.</li>
		</ul></td>
	</tr>
	<tr>
		<td><strong>Tags</strong></td><td><tt>spring-boot-cli-&lang;version&rang;</tt></td>
	</tr>
</table>
Tags are printed to standard output by the buildpack detect script


## Configuration
The container can be configured by modifying the [`config/springbootcli.yml`][springbootcli_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[springbootcli_yml]: ../config/springbootcli.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Spring Boot CLI repository index ([details][util_repositories]).
| `version` | The version of Spring Boot CLI to use. Candidate versions can be found in [this listing][spring_boot_cli_index_yml].

[spring_boot_cli_index_yml]: http://download.pivotal.io.s3.amazonaws.com/spring-boot-cli/lucid/x86_64/index.yml
