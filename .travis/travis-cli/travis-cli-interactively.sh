#!/bin/bash

docker run -it --rm -v $(pwd):/project --entrypoint=/bin/sh travis-cli 
