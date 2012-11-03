ROLL
====

Simple directory manager.

Usage
-----

    roll list [query]
    roll down [query]
    roll up [query]
    roll away [query]
    roll in [query]

Query syntax
------------

One of:

 - (dot) - all files in rollfile
 - @categoryName
 - comma sepearated list of package names

Drivers
-------

 - nop (does nothing)
 - http-file
 - cp-file
 - cp-dir
 - ftp-file
 - ftp-dir
 - fossil
 - git

Desing goals
------------

 - easy to implement
 - as simple as possible
 - heterogenous sources

What is it not
--------------

 - version control system
 - profi deploy tool

Rollfile entry structure
------------------------

Note dollar sign ($) used to denote variables.

    [$packageName]
    type=$driverType
    remote=$remoteURL
    local=$localFolder
    tags=$spaceSeparatedTags
    info=$infoText
    author=$authorName
    license=$licenseName