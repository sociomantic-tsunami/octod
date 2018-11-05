Disclaimer
==========

This project is now archived/abandoned as it was always used only by one
application ([neptune](https://github.com/sociomantic-tsunami/neptune)), and
the code was moved to it. This project is only kept for historical reasons, but
if you want to reuse the code you should probably check out neptune.

Description
===========

`octod` is a library for easy interaction with GitHub API. It consists of one
core module providing HTTP connection struct and many optional ones wrapping
various parts of API.

The mentioned `octod.core` module is the only necessary bit of functionality. It
augments vibe.d HTTP connection with GitHub auth and paging support. All other
modules implement trivial wrappers for specific API methods - those provide only
small extra convenience and are added on demand.
