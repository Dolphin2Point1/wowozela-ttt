#!/bin/bash

WORKSHOP_ID=2976397303

if [[ "$OSTYPE" == "darwin"* ]]; then
    gmad="$GMOD/bin/gmad"
    gmpublish="$GMOD/gmpublish"
else 
    gmad="$GMOD/bin/gmad_linux"
    gmpublish="$GMOD/bin/gmpublish_linux"
fi

export LD_LIBRARY_PATH="$GMOD/bin/"

$gmad create -folder "./" -out "_TEMP.gma"
$gmpublish update -addon "_TEMP.gma" -id "$WORKSHOP_ID" -icon "icon.jpg"

rm ./_TEMP.gma
