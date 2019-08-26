#!/bin/bash

docker run -v $(pwd):/project travis-cli $1
