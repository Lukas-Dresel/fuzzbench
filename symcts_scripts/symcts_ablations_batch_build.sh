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

BATCH_NUM=$1

FUZZERS=(symcc_aflplusplus symcts_afl)
FUZZERS+=(
    symcts_afl_ablation_scheduling_symcc
    symcts_afl_ablation_coverage_edge_coverage
    symcts_afl_ablation_mutation_full_solve_first
    symcts_afl_ablation_sync_always_sync
    symcts_afl_ablation_symcts_as_symcc
)
case $BATCH_NUM in
    1)
        TARGETS=(bloaty_fuzz_target stb_stbi_read_fuzzer )
        EXPERIMENT_NAME="ablt-blty-stbi-$(date +%Y%m%d-%H%M%S)"
        ;;
    2)
        TARGETS=(openh264_decoder_fuzzer sqlite3_ossfuzz)
        EXPERIMENT_NAME="ablt-o264-sqlt-$(date +%Y%m%d-%H%M%S)"
        ;;
    3)
        TARGETS=(libxml2_xml openthread_ot-ip6-send-fuzzer)
        EXPERIMENT_NAME="ablt-lxml-ot-$(date +%Y%m%d-%H%M%S)"
        ;;
    *)
        echo "Invalid BATCH_NUM: $BATCH_NUM"
        exit 1
        ;;
esac

# TARGETS=(
#     bloaty_fuzz_target
#     curl_curl_fuzzer_http
#     freetype2_ftfuzzer
#     harfbuzz_hb-shape-fuzzer
#     jsoncpp_jsoncpp_fuzzer
#     lcms_cms_transform_fuzzer
#     libjpeg-turbo_libjpeg_turbo_fuzzer
#     libpcap_fuzz_both
#     libpng_libpng_read_fuzzer
#     libxml2_xml
#     libxslt_xpath
#     openh264_decoder_fuzzer
#     openssl_x509
#     openthread_ot-ip6-send-fuzzer
#     proj4_proj_crs_to_crs_fuzzer
#     re2_fuzzer
#     sqlite3_ossfuzz
#     stb_stbi_read_fuzzer
#     systemd_fuzz-link-parser
#     vorbis_decode_fuzzer
#     woff2_convert_woff2ttf_fuzzer
#     zlib_zlib_uncompress_fuzzer
# )

# openthread-2019-12-23 - honggfuzz doesn't build due to strlcpy not defined??
# sqlite3_ossfuzz - mksourceid


MAKEFILETARGETS=()

for target in ${TARGETS[@]}
do
    MAKEFILETARGETS+=(build-coverage-$target)
    for fuzzer in ${FUZZERS[@]}
    do
        MAKEFILETARGETS+=(build-$fuzzer-$target)
    done
done

set -x
# REMOVE build-symcc_aflplusplus-sqlite3_ossfuzz from the MAKEFILETARGETS
MAKEFILETARGETS=(${MAKEFILETARGETS[@]/build-symcc_aflplusplus-sqlite3_ossfuzz/})

echo ${MAKEFILETARGETS[@]}
make ${MAKEFILETARGETS[@]} -j4 -k
