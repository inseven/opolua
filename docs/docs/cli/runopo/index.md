---
title: runopo
---

# Usage

```plaintext
{% include_relative _help.txt %}
```

# Overview

Run OPL programs on the command line. This is only suitable for simple programs that do not use graphics. For any graphical program, run via the app (or from the command line, by passing to the Qt app with `opolua open <path>`.)

# Example

[simple.txt](https://github.com/inseven/opolua/blob/main/examples/Tests/simple.txt) compiled on a Psion Series 5:

```plaintext
$ ./bin/runopo.lua --noget examples/Tests/simple.opo
Hello world!
Waaaat
(Skipping get)
```
