---
---

<div class="banner">
    <div class="icon"><img src="/images/icon.png" /></div>
    <p class="tagline">{{ site.tagline }}</p>
</div>

<script>

    var index = 0;

    setInterval(() => {
        let carousel = document.getElementById("carousel")
        let imgs = carousel.children
        let previous = carousel.children[index]
        index = index + 1
        if (index >= imgs.length) {
            index = 0;
        }
        let next = carousel.children[index]
        next.classList.add("show")
        previous.classList.remove("show")
    }, 10000)

</script>

<div class="hero">
    <div id="carousel" class="screenshot-iphone-13-pro-landscape">
        <img class="show" src="/images/screenshot-programs.png">
        <img src="/images/files.png">
        <img src="/images/jumpy.png">
        <img src="/images/tile-fall.png">
        <img src="/images/vexed.png">
        <img src="/images/char-map.png">
    </div>
</div>

<p class="details">
    View MBM image files, OPL scripts, and AIF resources, listen to sound files, and run OPL scripts and programs from Psion and Psion-compatible computers on iOS and iPadOS.
</p>

<p class="app-store-link">
    <a href="/public-beta">Public Beta</a>
</p>
