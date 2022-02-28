#!/bin/bash

set -x

mkdir -p color
convert opoc.bmp BMP3:color/1.bmp
convert oplc.bmp BMP3:color/2.bmp
convert soundc.bmp BMP3:color/3.bmp
convert paintc.bmp BMP3:color/4.bmp

mkdir -p grayscale
convert opo.bmp BMP3:grayscale/1.bmp
convert opl.bmp BMP3:grayscale/2.bmp
convert sound.bmp BMP3:grayscale/3.bmp
convert paint.bmp BMP3:grayscale/4.bmp
