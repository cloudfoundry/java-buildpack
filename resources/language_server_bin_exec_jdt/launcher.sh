#!/bin/bash

if [ -z $2] then
    if [ -z $3] then
        moduleWs = "$2/$3"
    else 
        moduleWs = "$2"
    fi
    if [ -e -d "$HOME/jdt_ws_root/$moduleWs"] then
        echo 
    else
        mkdir $HOME/jdt_ws_root/$moduleWs
    fi
    exec $JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/jdt_ws_root/$moduleWs
else
    exec $JAVA_HOME/bin/java -Declipse.application=org.eclipse.jdt.ls.core.id1 -Dosgi.bundles.defaultStartLevel=4 -Declipse.product=org.eclipse.jdt.ls.core.product -Dlog.protocol=true -Dlog.level=ALL -noverify -Xmx1G -XX:+UseG1GC -XX:+UseStringDeduplication -jar ./plugins/org.eclipse.equinox.launcher_1.4.0.v20161219-1356.jar -configuration ./config_linux -data $HOME/jdt_ws_root
fi
