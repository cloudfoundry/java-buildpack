# Groovy Container
The Groovy Container allows a uncompiled (i.e. `*.groovy`) to be run.

<table>
	<tr>
		<td><strong>Detection Criterion</strong></td><td><ul>
			<li>A single <tt>.groovy</tt> file exists</li>
			<li>Mutliple <tt>.groovy</tt> files exist, and one of them is named <tt>main.groovy</tt> or <tt>Main.groovy</tt></li>
			<li>Mutliple <tt>.groovy</tt> files exist, and one of them has a <tt>main()</tt> method</li>
			<li>Mutliple <tt>.groovy</tt> files exist, and one of them is not a POGO</li>
			<li>Mutliple <tt>.groovy</tt> files exist, and one of them has a <tt>#!</tt> declaration</li>
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
