# Design
The buildpack is designed as a collection of components.  These components are divided into three types; _Containers_, _Frameworks_, and _JREs_.

## Container Components
Container components represent the way that an application will be run.  Container types range from traditional application servers and servlet containers to simple Java `main()` method execution.  This type of component is responsible for determining which container should be used, downloading and unpacking that container, and producing the command that will be executed by Cloud Foundry at runtime.

Only a single container component can run an application.  If more than one container can be used, an error will be raised and application staging will fail.

## Framework Components
Framework components represent additional behavior or transformations used when an application is run.  Framework types include the downloading of JDBC JARs for bound services and automatic reconfiguration of `DataSource`s in Spring configuration to match bound services.  This type of component is responsible for determining which frameworks are required, transforming the application, and contributing any additional options that should be used at runtime.

Any number of framework components can be used when running an application.

## JRE Components
JRE components represent the JRE that will be used when running an application.  This type of component is responsible for determining which JRE should be used, downloading and unpacking that JRE, and resolving any JRE-specific options that should be used at runtime.

Only a single JRE component can be used to run an application.  If more than one JRE can be used, an error will be raised and application deployment will fail.
