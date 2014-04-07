Lila.lua
========

An application launcher using dmenu: http://tools.suckless.org/dmenu/

Advantages over dmenu_run:
- ranks applications by extremely sophisticated rules, taking into account the time of the last access and the number of accesses
- append ';' to an application name to open it in a terminal
- some keywords (which can be changed in the source file) do cool things:
    - type into dmenu something like `application --with --args ist myapp` to create an alias `myapp` for `application --with --args`
    - something like `application weg` removes the command (or an alias) for now and for evermore
    - `aktualisieren` runs dmenu_path to update the list with new applications
    - `debian-aktualisieren` runs update-menus, a command available only on Debian based systems, and updates the list with its result
