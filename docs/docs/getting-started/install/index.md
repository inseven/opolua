---
title: Install OpoLua
priority: 100
---

# iOS

Download from the App Store:

<a href="https://apps.apple.com/app/opolua/id1604029880"><img src="/images/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" /></a><br/>

# macOS

Download from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).

# Linux

## Debian and Ubuntu

There are currently pre-built amd64 and arm64 binaries for Ubuntu 24.04 (Noble Numbat), 25.04 (Plucky Puffin), 25.10 (Questing Quokka), and Debian 13 (Trixie).

Install from our apt repository:

```sh
curl -fsSL https://releases.jbmorley.co.uk/apt/public.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/jbmorley.gpg
echo "deb https://releases.jbmorley.co.uk/apt $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/jbmorley.list
sudo apt update
sudo apt install opolua
```

You can also download these from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).

## Arch

Download from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).

# Windows

Download from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).
