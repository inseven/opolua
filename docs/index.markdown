---
---

<div class="banner">
    <div class="icon"><img src="/images/icon.png" /></div>
    <p class="tagline">{{ site.tagline }}</p>
</div>

<style>

    #carousel img {
        transition: opacity 2s ease-in-out;
        opacity: 0;
    }

    #carousel img.show {
        opacity: 1;
    }

</style>

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
        <img class="show" src="/images/hero.png">
        <img src="/images/jumpy.png">
        <img src="/images/tile-fall.png">
        <img src="/images/vexed.png">
    </div>
</div>

<p class="details">
    View MBM image files, OPL scripts, and AIF resources, and run OPL scripts and programs from Psion and Psion-compatible computers running the EPOC operating system on iOS and iPadOS.
</p>
