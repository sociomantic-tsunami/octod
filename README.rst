Description
===========

`octod` is a library for easy interaction with GitHub API. It consists of one
core module providing HTTP connection struct and many optional ones wrapping
various parts of API.

The mentioned `octod.core` module is the only necessary bit of functionality. It
augments vibe.d HTTP connection with GitHub auth and paging support. All other
modules implement trivial wrappers for specific API methods - those provide only
small extra convenience and are added on demand.
