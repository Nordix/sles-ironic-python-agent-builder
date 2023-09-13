#!/bin/bash

docker run -ti  \
-v "/home/adam/test/sles_ipa_2022-10-19-1:/ipa_builder" \
-v "/tmp:/tmp" \
-v "/home/adam/sles_images:/root/sles_images" \
--env-file="./envfile" \
quay.io/centos/centos:8 bin/bash
