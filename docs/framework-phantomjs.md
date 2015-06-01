# PhantomJS Framework
Add PhantomJS binary for Highcharts export server when docker is not an option or refactoring the highcharts export server to use PhantomJS as a separate service is not an option.

<table>
  <tr>
    <td><strong>Detection Criterion</strong></td>
    <td>Existence of a export-servlet.xml file inside the application archive. This file should be present in every highcharts-export-web.
    </td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td>
    <td><tt>phantomjs=&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
For general information on configuring the buildpack, refer to [Configuration and Extension][].

The framework can be configured by modifying the [`config/phantom_js.yml`][] file in the buildpack fork.  The framework uses the [`Repository` utility support][repositories] and so it supports the [version syntax][] defined there.

[HighchartsExportServer]: http://www.highcharts.com/docs/export-module/setting-up-the-server
[PhantomsJS]: http://phantomjs.org/
