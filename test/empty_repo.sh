#!/bin/bash
cd "${0%/*}"
mkdir $1
cd $1
hg init
