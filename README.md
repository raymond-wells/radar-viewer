# Radar Viewer

## Overview

Displays weather radar images over on an OpenStreetMap widget. The purpose of this application is to develop a general purpose 
radar image viewer as a collection of widgets that may find their way into a larger application, though it may be useful in and of itself as
a standalone application.

## License

See [COPYING](COPYING) for details.

## Requirements

* Zig Master (target version 0.12.0) 
* Gtk+-4.0
* Shumate 1.0 (libshumate)
* Libsoup 3.0

## Building & Testing

This is a standard Zig project using the Zig build system. See https://www.ziglang.org for further information.

To build & run:

```bash
zig build run
```

To run tests:

``` shell
zig build tests
```

# Data Sources & Caches

## Remote Data Sources

* https://www.weather.gov/tg/general - For weather radar scan data.

## Local Caches

* Radar Scan Cache: `$XDG_CACHE_HOME/.cache/org.rwells.RadarViewer`
