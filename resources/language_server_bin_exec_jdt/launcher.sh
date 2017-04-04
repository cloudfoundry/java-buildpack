#!/bin/bash
export STDIN_PORT=8991
export STDOUT_PORT=8990
$JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/language_server_bin_exec_jdt/jdt_ws_root 2>&1