# Debugging the Buildpack
The buildpack is designed to be easy to configure and extend, but it is still possible that something will go wrong.  A configuration property might have an invalid value, or a new component may conflict with an existing one.  When these problems happen, the buildpack can tell you quite a bit about what went wrong.

## Debug Logging
By default the buildpack is very quiet, only informing you about big things going right.  Behind the scenes however, it logs an incredible amount of information about each attempt at staging.  If your application has staged and is running, but not the way you expected it to, you can get the contents of the debug log by running the following command

```bash
cf files <APP> app/.java-buildpack.log
```

If staging fails completely there is no instance that you can query for that file.  In that case, you need to cause the [debug logging][d] to print to the console and capture it there.  To configure this, run the following command and then push your application again.

```bash
cf set-env <APP> JBP_LOG_LEVEL DEBUG
```

In either case, the output will look like the following:

```text
# Logfile created on 2014-04-25 08:06:06 +0000 by logger.rb/31641
2014-04-25T08:06:06.01+0000 [ConfigurationUtils]             DEBUG No configuration file /tmp/buildpacks/java-buildpack/config/version.yml found
2014-04-25T08:06:06.04+0000 [BuildpackVersion]               DEBUG 9d0293b | https://github.com/cloudfoundry/java-buildpack#9d0293b
2014-04-25T08:06:06.04+0000 [Buildpack]                      DEBUG Environment Variables: {"USER"=>"vcap", "VCAP_APPLICATION"=>"{...}", "STAGING_TIMEOUT"=>"900.0", "PATH"=>"/bin:/usr/bin", "PWD"=>"/home/vcap", "VCAP_SERVICES"=>"{...}", "SHLVL"=>"1", "HOME"=>"/home/vcap", "BUILDPACK_CACHE"=>"/var/vcap/packages/buildpack_cache", "DATABASE_URL"=>"", "MEMORY_LIMIT"=>"512m", "_"=>"/usr/bin/ruby"}
2014-04-25T08:06:06.04+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/components.yml: {"containers"=>["JavaBuildpack::Container::DistZip", "JavaBuildpack::Container::Groovy", "JavaBuildpack::Container::JavaMain", "JavaBuildpack::Container::PlayFramework", "JavaBuildpack::Container::Ratpack", "JavaBuildpack::Container::SpringBoot", "JavaBuildpack::Container::SpringBootCLI", "JavaBuildpack::Container::Tomcat"], "jres"=>["JavaBuildpack::Jre::OpenJdkJRE"], "frameworks"=>["JavaBuildpack::Framework::AppDynamicsAgent", "JavaBuildpack::Framework::JavaOpts", "JavaBuildpack::Framework::MariaDbJDBC", "JavaBuildpack::Framework::NewRelicAgent", "JavaBuildpack::Framework::PlayFrameworkAutoReconfiguration", "JavaBuildpack::Framework::PlayFrameworkJPAPlugin", "JavaBuildpack::Framework::PostgresqlJDBC", "JavaBuildpack::Framework::SpringAutoReconfiguration", "JavaBuildpack::Framework::SpringInsight"]}
2014-04-25T08:06:06.04+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Jre::OpenJdkJRE
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Jre::OpenJdkJRE
2014-04-25T08:06:06.10+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/open_jdk_jre.yml: {"repository_root"=>"{default.repository.root}/openjdk/{platform}/{architecture}", "version"=>"1.7.0_+", "memory_sizes"=>{"permgen"=>"64m.."}, "memory_heuristics"=>{"heap"=>75, "permgen"=>10, "stack"=>5, "native"=>10}}
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::AppDynamicsAgent
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::AppDynamicsAgent
2014-04-25T08:06:06.10+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/app_dynamics_agent.yml: {"version"=>"3.7.+", "repository_root"=>"{default.repository.root}/app-dynamics", "tier_name"=>"Cloud Foundry"}
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::JavaOpts
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::JavaOpts
2014-04-25T08:06:06.10+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/java_opts.yml: {"from_environment"=>true}
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::MariaDbJDBC
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::MariaDbJDBC
2014-04-25T08:06:06.10+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/maria_db_jdbc.yml: {"version"=>"1.1.+", "repository_root"=>"{default.repository.root}/mariadb-jdbc"}
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::NewRelicAgent
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::NewRelicAgent
2014-04-25T08:06:06.10+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/new_relic_agent.yml: {"version"=>"3.6.+", "repository_root"=>"{default.repository.root}/new-relic"}
2014-04-25T08:06:06.10+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::PlayFrameworkAutoReconfiguration
2014-04-25T08:06:06.11+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::PlayFrameworkAutoReconfiguration
2014-04-25T08:06:06.11+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/play_framework_auto_reconfiguration.yml: {"version"=>"0.+", "repository_root"=>"{default.repository.root}/auto-reconfiguration"}
2014-04-25T08:06:06.11+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::PlayFrameworkJPAPlugin
2014-04-25T08:06:06.11+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::PlayFrameworkJPAPlugin
2014-04-25T08:06:06.11+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/play_framework_jpa_plugin.yml: {"version"=>"0.+", "repository_root"=>"{default.repository.root}/play-jpa-plugin"}
2014-04-25T08:06:06.12+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::PostgresqlJDBC
2014-04-25T08:06:06.12+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::PostgresqlJDBC
2014-04-25T08:06:06.12+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/postgresql_jdbc.yml: {"version"=>"9.3.+", "repository_root"=>"{default.repository.root}/postgresql-jdbc"}
2014-04-25T08:06:06.12+0000 [Buildpack]                      DEBUG Instantiating JavaBuildpack::Framework::SpringAutoReconfiguration
2014-04-25T08:06:06.15+0000 [Buildpack]                      DEBUG Successfully required JavaBuildpack::Framework::SpringAutoReconfiguration
2014-04-25T08:06:06.15+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/spring_auto_reconfiguration.yml: {"version"=>"0.+", "repository_root"=>"{default.repository.root}/auto-reconfiguration"}
2014-04-25T08:06:06.15+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/repository.yml: {"default_repository_root"=>"http://download.run.pivotal.io"}
2014-04-25T08:06:06.21+0000 [RepositoryIndex]                DEBUG {default.repository.root}/auto-reconfiguration expanded to http://download.run.pivotal.io/auto-reconfiguration
2014-04-25T08:06:06.21+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/cache.yml: {"remote_downloads"=>"enabled"}
2014-04-25T08:06:06.22+0000 [DownloadCache]                  DEBUG Proxy: , , ,
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG HTTP: download.run.pivotal.io, 80, {:read_timeout=>10, :connect_timeout=>10, :open_timeout=>10, :use_ssl=>false}
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Request: /auto-reconfiguration/index.yml, {"accept"=>["*/*"], "user-agent"=>["Ruby"]}
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Status: 200
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Persisting etag: "d093ebc9c94d3050c28898585611701c"
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Persisting last-modified: Thu, 24 Apr 2014 10:47:19 GMT
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Persisting content to /tmp/http:%2F%2Fdownload.run.pivotal.io%2Fauto-reconfiguration%2Findex.yml.cached
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Validated content size 1174 is 1174
2014-04-25T08:06:06.25+0000 [RepositoryIndex]                DEBUG {"0.6.8"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.6.8.jar", "0.7.0"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.7.0.jar", "0.7.1"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.7.1.jar", "0.7.2"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.7.2.jar", "0.8.0"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.0.jar", "0.8.1"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.1.jar", "0.8.2"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.2.jar", "0.8.3"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.3.jar", "0.8.4"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.4.jar", "0.8.5"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.5.jar", "0.8.6"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.6.jar", "0.8.7"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.7.jar", "0.8.8"=>"http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.8.jar"}

...

2014-04-25T08:06:08.83+0000 [MemoryBucket]                   DEBUG #<JavaBuildpack::Jre::MemoryBucket:0x000000020e57c0 @name="heap", @weighting=75, @range=0..>
2014-04-25T08:06:08.83+0000 [MemoryBucket]                   DEBUG #<JavaBuildpack::Jre::MemoryBucket:0x000000020ed510 @name="permgen", @weighting=10, @range=64M..>
2014-04-25T08:06:08.83+0000 [MemoryBucket]                   DEBUG #<JavaBuildpack::Jre::StackMemoryBucket:0x000000020ec9a8 @name="stack", @weighting=5, @range=0..>
2014-04-25T08:06:08.84+0000 [MemoryBucket]                   DEBUG #<JavaBuildpack::Jre::MemoryBucket:0x000000020ebf30 @name="native", @weighting=10, @range=0..>
2014-04-25T08:06:08.84+0000 [MemoryBucket]                   DEBUG #<JavaBuildpack::Jre::MemoryBucket:0x000000020ea568 @name="normalised stack", @weighting=5, @range=0..>
2014-04-25T08:06:08.84+0000 [Buildpack]                      DEBUG Release Payload
---
addons: []
config_vars: {}
default_process_types:
  web: JAVA_HOME=$PWD/.java-buildpack/open_jdk_jre JAVA_OPTS="-Djava.io.tmpdir=$TMPDIR
    -XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk_jre/bin/killjava.sh -Xmx382293K
    -Xms382293K -XX:MaxPermSize=64M -XX:PermSize=64M -Xss995K -Dalpha=bravo -Dhttp.port=$PORT"
    $PWD/.java-buildpack/tomcat/bin/catalina.sh run
```

The example content here has been trimmed so that it's not overwhelming, but nearly every component in the buildpack will output something useful as it works.

## Running the Buildpack Locally
Sometimes logging just isn't going to cut it for debugging.  There are times when using a debugger or a local filesystem is the only way to diagnose problems.  A simple and surprisingly effective way of troubleshooting buildpacks is actually to skip all of Cloud Foundry and run the buildpack locally.  The buildpack API consists of three bash scripts.  This means that if you've got a filesystem that looks like what Cloud Foundry will be presented plus a local copy of your buildpack, you can run the bash scripts locally.  You might see something like this:

```bash
$ mkdir -p target/exploded
$ cd target/exploded
$ jar xf ../web-application-1.0.0-BUILD-SNAPSHOT.war

$ <BUILDPACK-CLONE>/bin/detect .
java-buildpack=ded1e56-https://github.com/cloudfoundry/java-buildpack#ded1e56 open-jdk-jre=1.7.0_51 spring-auto-reconfiguration=0.8.7 tomcat-instance=7.0.53 tomcat-lifecycle-support=2.1.0_RELEASE tomcat-logging-support=2.1.0_RELEASE

$ <BUILDPACK-CLONE>/bin/compile . $TMPDIR
-----> Java Buildpack Version: ded1e56 | https://github.com/cloudfoundry/java-buildpack#ded1e56
-----> Downloading Open Jdk JRE 1.7.0_51 from http://download.run.pivotal.io/openjdk/mountainlion/x86_64/openjdk-1.7.0_51.tar.gz (5.0s)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (0.4s)
-----> Downloading Spring Auto Reconfiguration 0.8.7 from http://download.run.pivotal.io/auto-reconfiguration/auto-reconfiguration-0.8.7.jar (0.3s)
       Modifying /WEB-INF/web.xml for Auto Reconfiguration
-----> Downloading Tomcat Instance 7.0.53 from http://download.run.pivotal.io/tomcat/tomcat-7.0.53.tar.gz (1.1s)
       Expanding Tomcat to .java-buildpack/tomcat (0.0s)
-----> Downloading Tomcat Lifecycle Support 2.1.0_RELEASE from http://download.run.pivotal.io/tomcat-lifecycle-support/tomcat-lifecycle-support-2.1.0_RELEASE.jar (0.2s)
-----> Downloading Tomcat Logging Support 2.1.0_RELEASE from http://download.run.pivotal.io/tomcat-logging-support/tomcat-logging-support-2.1.0_RELEASE.jar (0.1s)

$ <BUILDPACK-CLONE>/bin/release .
---
addons: []
config_vars: {}
default_process_types:
  web: JAVA_HOME=$PWD/.java-buildpack/open_jdk_jre JAVA_OPTS="-Djava.io.tmpdir=$TMPDIR
    -XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk_jre/bin/killjava.sh -XX:MaxPermSize=64M
    -XX:PermSize=64M -Dhttp.port=$PORT" $PWD/.java-buildpack/tomcat/bin/catalina.sh
    run

$ JAVA_HOME=$PWD/.java-buildpack/open_jdk_jre JAVA_OPTS="-Djava.io.tmpdir=$TMPDIR -XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk_jre/bin/killjava.sh -XX:MaxPermSize=64M -XX:PermSize=64M -Dhttp.port=$PORT" $PWD/.java-buildpack/tomcat/bin/catalina.sh run
...
```

You must be careful that path you run from is the same as the path Cloud Foundry will be presented with.  In the case of an exploded filesystem, nothing is different.  However, when pushing an archive (e.g. `JAR`, `WAR`, `ZIP`) Cloud Foundry presents the buildpack with an exploded copy of that archive and you must do the same.  As described in the **Debug Logging** section above, both file and console debug output are available.  To get console output you run the commands as follows:

```bash
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/detect .
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/compile . $TMPDIR
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/release .
```

[d]: extending-logging.md#configuration
