#!/bin/bash

WORKSHOP_ID=108170491

if [[ "$OSTYPE" == "darwin"* ]]; then
    gmad="$GMOD/bin/gmad"
    gmpublish="$GMOD/gmpublish"
else 
    gmad="$GMOD/bin/gmad_linux"
    gmpublish="$GMOD/gmpublish_linux"
fi

export LD_LIBRARY_PATH="$GMOD/bin/"

$gmad create -folder "./" -out "_TEMP.gma"
$gmpublish update -addon "_TEMP.gma" -id "$WORKSHOP_ID" -icon "icon.jpg"

rm ./_TEMP.gma
