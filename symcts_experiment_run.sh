#!/bin/bash


# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FUZZERS=(symcc_aflplusplus symsan honggfuzz libfuzzer symcts symcts_afl symcts_symqemu_afl aflplusplus)
# TARGETS=(curl_curl_fuzzer_http harfbuzz_hb-shape-fuzzer jsoncpp_jsoncpp_fuzzer libpng_libpng_read_fuzzer libxml2_xml libxslt_xpath mbedtls_fuzz_dtlsclient openssl_x509 php_php-fuzz-parser re2_fuzzer vorbis_decode_fuzzer woff2_convert_woff2ttf_fuzzer zlib_zlib_uncompress_fuzzer)

# TARGETS=(openssl_x509 re2_fuzzer vorbis_decode_fuzzer woff2_convert_woff2ttf_fuzzer zlib_zlib_uncompress_fuzzer)

FUZZERS=(symcc_aflplusplus symsan symcts_symqemu_afl afl_companion symcts_symqemu aflplusplus)
TARGETS=(
    stb_stbi_read_fuzzer
    libpng_libpng_read_fuzzer
    curl_curl_fuzzer_http
    vorbis_decode_fuzzer
    woff2_convert_woff2ttf_fuzzer
    zlib_zlib_uncompress_fuzzer
)

# 2 runs * 6 fuzzers * 6 benchmarks = 72 cores

EXPERIMENT_NAME="symcts-$(date +%Y%m%d-%H%M%S)"

# --benchmarks libpng-1.2.56
# libpcap_fuzz_both vorbis-2017-12-11 woff2-2016-05-06 zlib_zlib_uncompress_fuzzer
# --no-seeds \

# use python3.10 if it exists, otherwise use python3.8 if it exists, otherwise use python3
PYTHON3=$(which python3.10 || which python3.8 || which python3)

    # --no-seeds \
    # --no-dictionaries \

PYTHONPATH=. "$PYTHON3" experiment/run_experiment.py \
    --no-seeds \
    --no-dictionaries \
    --allow-uncommitted-changes \
    --experiment-config symcts_experiment_config.yaml \
    --concurrent-builds 1 \
    --runners-cpus 72 \
    --measurers-cpus 24 \
    --experiment-name $EXPERIMENT_NAME \
    --fuzzers "${FUZZERS[@]}" \
    --benchmarks "${TARGETS[@]}" \
