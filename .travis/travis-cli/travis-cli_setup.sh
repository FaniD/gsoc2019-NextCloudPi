#!/bin/bash

docker build .travis/travis-cli/ -t travis-cli
echo "alias travis='./.travis/travis-cli/travis-cli.sh'" >> ~/.bashrc

