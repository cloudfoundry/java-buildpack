#!/bin/bash
#declare -i STDIN_PORT=8991; export STDIN_PORT
#declare -i STDOUT_PORT=8990; export STDOUT_PORT
#
#kill_lsp () {
#    pkill -P $BASHPID
#}
#trap kill_lsp TERM
exec $JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/jdt_ws_root
