#!/bin/bash

if [ -n "$2" ]; then
if [ -n "$3" ]; then
    moduleWs="$2/$3"
else 
    moduleWs="$2"
fi

if [ -d "$HOME/jdt_ws_root/$moduleWs"  ] && [ -n "$moduleWs" ]; then
    echo "Already exists $moduleWs"
else
    echo "Create $HOME/jdt_ws_root/$moduleWs"
    mkdir $HOME/jdt_ws_root/$moduleWs
fi
    exec $JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/jdt_ws_root/$moduleWs
else
    exec $JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/jdt_ws_root
fi
