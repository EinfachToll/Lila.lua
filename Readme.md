Lila.lua
========

An application launcher using dmenu: http://tools.suckless.org/dmenu/

Advantages over dmenu_run:
- ranks applications by extremely sophisticated rules, taking into account the time of the last access and the number of accesses
- append ';' to an application name to open it in a terminal
- some keywords which can be set in the source file do cool things:
    - type into dmenu something like "application --with --args is now myapp" to create an alias called "myapp"
    - something like "application gets away" removes the command (or an alias) for now and for evermore
    - "update" runs dmenu_path to update the list with new applications
    - "update-debian" runs update-menus, which is available only on Debian based systems, and updates the list with its result
