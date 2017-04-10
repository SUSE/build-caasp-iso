# `build-caasp-iso`

`build-caasp-iso` is a script that allows you to build a CaaSP ISO locally. It has been part of the
2017 Hackweek project at SUSE.

It will checkout the DVD product and build the ISO image locally.

The kiwi definition will be used as a source and modified, merging some buildinfo information into
it, and generating a new kiwi file, that will be used as a source to build the ISO images.

This means that you can modify the original kiwi definition in order to include packages that you
copypac'ed into your home (for example) and give those repositories higher priorities, so your
own packages will be included in the locally generated ISO instead of the "official" ones.

This process consumes a lot of disk space -- and is what makes the process much faster after the
first execution.

## Executing

As of now, the program does not contain arguments or flags, so it's a raw `ruby build-caasp-iso.rb`.

The first time it will take some time to download and populate the package cache, but it will be
much faster on the following builds (~ 1 minute for each build after the first one).

## Local configuration

This script wraps [osc](https://en.opensuse.org/openSUSE:OSC) and your `~/.oscrc` file must contain the following entries:

```
apiurl = https://api.suse.de

[https://api.suse.de]
user= youruser
pass= yourpass
```

## License

```
Copyright (C) 2017 SUSE LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```
