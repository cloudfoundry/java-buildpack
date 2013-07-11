# Play Container
The Play Container allows Play applications to be run.

<table>
  <tr>
    <td><strong>Detection Criteria</strong></td><td>The files <tt>start</tt> and <tt>lib/play.play_*.jar</tt> (or <tt>staged/play_*.jar</tt>) exist in the application
	directory or one of its immediate subdirectories (but not in both)</td>
  </tr>
  <tr>
    <td><strong>Tags</strong></td><td><tt>play-&lt;version&gt;</tt></td>
  </tr>
</table>
Tags are printed to standard output by the buildpack detect script

## Configuration
The Play Container cannot be configured.


