---
title: Install OpoLua
priority: 100
---

# iOS

Download from the App Store:

<a href="https://apps.apple.com/app/opolua/id1604029880"><img src="/images/Download_on_the_App_Store_Badge_US-UK_RGB_blk_092917.svg" /></a><br/>

# macOS

Download from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).

# Ubuntu

Install from our apt repository:

```sh
curl -fsSL https://releases.jbmorley.co.uk/apt/public.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/jbmorley.gpg
echo "deb https://releases.jbmorley.co.uk/apt $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/jbmorley.list
sudo apt update
sudo apt install opolua
```

# Windows

Download from [GitHub](https://github.com/inseven/opolua/releases/tag/{{ site.env.VERSION_NUMBER }}).
