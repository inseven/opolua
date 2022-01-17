#!/usr/bin/env bash

IMAGE=$1
MASK=$2

convert "$MASK" -alpha off -negate "$IMAGE" +swap -compose copyalpha -composite image.png
