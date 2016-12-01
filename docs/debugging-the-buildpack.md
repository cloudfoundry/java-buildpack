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
2014-04-25T08:06:06.15+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/repository.yml: {"default_repository_root"=>"https://java-buildpack.cloudfoundry.org"}
2014-04-25T08:06:06.21+0000 [RepositoryIndex]                DEBUG {default.repository.root}/auto-reconfiguration expanded to https://java-buildpack.cloudfoundry.org/auto-reconfiguration
2014-04-25T08:06:06.21+0000 [ConfigurationUtils]             DEBUG Configuration from /tmp/buildpacks/java-buildpack/config/cache.yml: {"remote_downloads"=>"enabled"}
2014-04-25T08:06:06.22+0000 [DownloadCache]                  DEBUG Proxy: , , ,
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG HTTP: java-buildpack.cloudfoundry.org, 80, {:read_timeout=>10, :connect_timeout=>10, :open_timeout=>10, :use_ssl=>false}
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Request: /auto-reconfiguration/index.yml, {"accept"=>["*/*"], "user-agent"=>["Ruby"]}
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Status: 200
2014-04-25T08:06:06.24+0000 [DownloadCache]                  DEBUG Persisting etag: "d093ebc9c94d3050c28898585611701c"
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Persisting last-modified: Thu, 24 Apr 2014 10:47:19 GMT
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Persisting content to /tmp/http:%2F%2Fjava-buildpack.cloudfoundry.org%2Fauto-reconfiguration%2Findex.yml.cached
2014-04-25T08:06:06.25+0000 [DownloadCache]                  DEBUG Validated content size 1174 is 1174
2014-04-25T08:06:06.25+0000 [RepositoryIndex]                DEBUG {"0.6.8"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.6.8.jar", "0.7.0"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.7.0.jar", "0.7.1"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.7.1.jar", "0.7.2"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.7.2.jar", "0.8.0"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.0.jar", "0.8.1"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.1.jar", "0.8.2"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.2.jar", "0.8.3"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.3.jar", "0.8.4"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.4.jar", "0.8.5"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.5.jar", "0.8.6"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.6.jar", "0.8.7"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.7.jar", "0.8.8"=>"https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-0.8.8.jar"}

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
Sometimes logging just isn't going to cut it for debugging. There are times when using a debugger or a local filesystem is the only way to diagnose problems.  A simple and surprisingly effective way of troubleshooting buildpacks is actually to skip all of Cloud Foundry and run the buildpack locally.

### Requirements

The buildpack API consists of three bash scripts. This means that if you've got a Unix like environment with Ruby installed at an appropriate level, a filesystem that looks like what Cloud Foundry will present to the buildpack and a local copy of your buildpack, you can run the bash scripts locally.

### Example invocation

You might see something like this:

```bash
$ mkdir exploded
$ cd exploded
$ unzip ../play-application-1.0.0.BUILD-SNAPSHOT.zip
$ export VCAP_SERVICES="{\"user-provided\":[{\"name\":\"app-dynamics-test\",\"label\":\"user-provided\",\"tags\":[],\"credentials\":{\"host-name\":\"[REDACTED]\",\"port\":\"443\",\"ssl-enabled\":\"true\",\"account-name\":\"[REDACTED]\",\"account-access-key\":\"[REDACTED]\"}}]}"

$ $BUILDPACK_ROOT/bin/detect .
app-dynamics-agent=3.8.4 java-buildpack=0fab02b-https://github.com/cloudfoundry/java-buildpack.git#0fab02b open-jdk-jre=1.7.0_60 play-framework-auto-reconfiguration=1.4.0_RELEASE play-framework=2.2.3 spring-auto-reconfiguration=1.4.0_RELEASE

$ $BUILDPACK_ROOT/bin/compile . $TMPDIR
-----> Java Buildpack Version: 0fab02b | https://github.com/cloudfoundry/java-buildpack.git#0fab02b
-----> Downloading Open Jdk JRE 1.7.0_60 from https://java-buildpack.cloudfoundry.org/openjdk/mountainlion/x86_64/openjdk-1.7.0_60.tar.gz (found in cache)
       Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (0.4s)
-----> Downloading App Dynamics Agent 3.8.4 from https://java-buildpack.cloudfoundry.org/app-dynamics/app-dynamics-3.8.4.zip (found in cache)
       Expanding App Dynamics Agent to .java-buildpack/app_dynamics_agent (0.1s)
-----> Downloading Play Framework Auto Reconfiguration 1.4.0_RELEASE from https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-1.4.0_RELEASE.jar (found in cache)
-----> Downloading Spring Auto Reconfiguration 1.4.0_RELEASE from https://java-buildpack.cloudfoundry.org/auto-reconfiguration/auto-reconfiguration-1.4.0_RELEASE.jar (found in cache)

$ $BUILDPACK_ROOT/bin/release . | ruby -e "require \"yaml\"; puts YAML.load(STDIN.read)[\"default_process_types\"][\"web\"]"
PATH=$PWD/.java-buildpack/open_jdk_jre/bin:$PATH JAVA_HOME=$PWD/.java-buildpack/open_jdk_jre $PWD/play-application-1.0.0.BUILD-SNAPSHOT/bin/play-application -J-Djava.io.tmpdir=$TMPDIR -J-XX:OnOutOfMemoryError=$PWD/.java-buildpack/open_jdk_jre/bin/killjava.sh -J-XX:MaxPermSize=64M -J-XX:PermSize=64M -J-javaagent:$PWD/.java-buildpack/app_dynamics_agent/javaagent.jar -J-Dappdynamics.agent.applicationName='' -J-Dappdynamics.agent.tierName='Cloud Foundry' -J-Dappdynamics.agent.nodeName=$(expr "$VCAP_APPLICATION" : '.*instance_id[": ]*"\([a-z0-9]\+\)".*') -J-Dappdynamics.agent.accountAccessKey=[REDACTED] -J-Dappdynamics.agent.accountName=[REDACTED] -J-Dappdynamics.controller.hostName=[REDACTED] -J-Dappdynamics.controller.port=443 -J-Dappdynamics.controller.ssl.enabled=true -J-Dhttp.port=$PORT
```

You can trigger different behaviour in the buildpack by setting the `VCAP_SERVICES` environment variable. For example, to fake the binding of a service.

You must be careful that path you run from is the same as the path Cloud Foundry will be presented with.  In the case of an exploded filesystem, nothing is different.  However, when pushing an archive (e.g. `JAR`, `WAR`, or `ZIP`) Cloud Foundry presents the buildpack with an exploded copy of that archive and you must do the same. As described in the **Debug Logging** section above, both file and console debug output are available. To get console output you run the commands as follows:

```bash
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/detect .
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/compile . $TMPDIR
JBP_LOG_LEVEL=DEBUG <BUILDPACK-CLONE>/bin/release .
```

##Aliases

Running the different stages of the buildpack lifecycle can be made simpler with the use of aliases and an environment variable to point at your local copy of the buildpack. The examples below pass in `.` to the scripts assuming you are calling them from the local working directory.

```bash
$ alias detect='$BUILDPACK_ROOT/bin/detect .'
$ alias compile='$BUILDPACK_ROOT/bin/compile . $TMPDIR'
$ alias release='$BUILDPACK_ROOT/bin/release . | ruby -e "require \"yaml\"; puts YAML.load(STDIN.read)[\"default_process_types\"][\"web\"]"'
```

[d]: extending-logging.md#configuration
