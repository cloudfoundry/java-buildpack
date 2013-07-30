# Groovy Container
The Groovy Container allows a uncompiled (i.e. `*.groovy`) to be run.

<table>
	<tr>
		<td><strong>Detection Criteria</strong></td><td><ul>
			<li>A <tt>.groovy</tt> file exists which has a <tt>main()</tt> method, or</li>
			<li>A <tt>.groovy</tt> file exists which is not a POGO (a POGO contains one or more classes), or</li>
			<li>A <tt>.groovy</tt> file exists which has a shebang (<tt>#!</tt>) declaration</li>
		</ul></td>
	</tr>
	<tr>
		<td><strong>Tags</strong></td><td><tt>groovy-&lang;version&rang;</tt></td>
	</tr>
</table>
Tags are printed to standard output by the buildpack detect script


## Configuration
The container can be configured by modifying the [`config/groovy.yml`][groovy_yml] file.  The container uses the [`Repository` utility support][util_repositories] and so it supports the [version syntax][version_syntax] defined there.

[groovy_yml]: ../config/groovy.yml
[util_repositories]: util-repositories.md
[version_syntax]: util-repositories.md#version-syntax-and-ordering

| Name | Description
| ---- | -----------
| `repository_root` | The URL of the Groovy repository index ([details][util_repositories]).
| `version` | The version of Groovy to use. Candidate versions can be found in [this listing][groovy_index_yml].

[groovy_index_yml]: http://download.pivotal.io.s3.amazonaws.com/groovy/lucid/x86_64/index.yml
