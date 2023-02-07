# Copyright 2021 Google LLC
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
''' Uses the SymCC-AFL hybrid from SymCC. '''

import os
import time
import shutil
import threading
import subprocess
import shutil

from fuzzers import utils
from fuzzers.afl import fuzzer as afl_fuzzer
from fuzzers.aflplusplus import fuzzer as aflplusplus_fuzzer


# def get_symcc_build_dir(target_directory):
#     """Return path to uninstrumented target directory."""
#     return os.path.join(target_directory, 'uninstrumented')


def build():
    """Build an AFL version and SymCC version of the benchmark"""
    print('Step 1: Building a vanilla version of the benchmark')
    new_env = os.environ.copy()
    new_env['OUT'] = "/out/target/vanilla"
    new_env['FUZZER_LIB'] = '/out/target/vanilla/afl_driver.o'
    utils.build_benchmark(env=new_env)

    # Save the environment for use in SymCC
    new_env = os.environ.copy()
    build_directory = os.environ['OUT']

    print('Step 2: Building with AFL')
    os.environ['OUT'] = '/out/target/cmplog/'
    src = os.getenv('SRC')
    work = os.getenv('WORK')
    with utils.restore_directory(src), utils.restore_directory(work):
        aflplusplus_fuzzer.build('cmplog', 'tracepc')

    # Copy the target binary so the experiment runner does not complain
    shutil.copy('/out/target/cmplog/' + os.environ['FUZZ_TARGET'], '/out/')


    print('Step 3: Completed AFL build')
    # Copy over AFL artifacts needed by SymCC.
    shutil.copy('/afl/afl-fuzz', build_directory)
    shutil.copy('/afl/afl-showmap', build_directory)

    # Build the SymCC-instrumented target.
    print('Step 4: Building the benchmark with SymCC')
    # Set flags to ensure compilation with SymCC.
    new_env['CC'] = '/symcc/build/symcc'
    new_env['CXX'] = '/symcc/build/sym++'
    new_env['CXXFLAGS'] = new_env['CXXFLAGS'].replace('-stlib=libc++', '')
    new_env['CXXFLAGS'] += ' -ldl -lm'
    # new_env['SYMCC_EXTRA_CFLAGS'] = '-l:libc_symcc_preload.a'
    # new_env['SYMCC_EXTRA_CXXFLAGS'] = '-l:libc_symcc_preload.a'
    new_env['SYMCC_EXTRA_CFLAGS'] = '-g'
    new_env['SYMCC_EXTRA_LDFLAGS'] = '-L /libs_symcc/ -l:libc_symcc_preload.a'
    new_env['FUZZER_LIB'] = '/libfuzzer-main.o'
    new_env['OUT'] = '/out/target/symcc/'
    new_env['LIBRARY_PATH'] = new_env.get('LIBRARY_PATH', '') + ":/libs_symcc/:/libs/"

    new_env['CXXFLAGS'] += ' -fno-sanitize=all '
    new_env['CFLAGS'] += ' -fno-sanitize=all '
    new_env['SYMCC_RUNTIME_DIR'] = "/libs_symcc/" # SymCC should look for the runtime in the same directory so our copying works
    new_env['LD_LIBRARY_PATH'] = new_env.get('LD_LIBRARY_PATH', '') + ":/libs_symcc/:/libs/"

    # Setting this environment variable instructs SymCC to use the
    # libcxx library compiled with SymCC instrumentation.
    new_env['SYMCC_LIBCXX_PATH'] = '/libcxx_native_build'

    # Instructs SymCC to consider no symbolic inputs at runtime. This is needed
    # if, for example, some tests are run during compilation of the benchmark.
    new_env['SYMCC_NO_SYMBOLIC_INPUT'] = '1'
    new_env['SYMCC_DISABLE_WRITING'] = "1" # needed for the symcts runtime to run during tests (missing shmem env vars)

    utils.build_benchmark(env=new_env)


def launch_afl_thread(input_corpus, output_corpus, target_binary,
                      additional_flags):
    """ Simple wrapper for running AFL. """
    afl_thread = threading.Thread(target=afl_fuzzer.run_afl_fuzz,
                                  args=(input_corpus, output_corpus,
                                        target_binary, additional_flags))
    afl_thread.start()
    return afl_thread


def fuzz(input_corpus, output_corpus, target_binary, with_afl=False):
    """
    Launches a master and a secondary instance of AFL, as well as
    the symcts instance.
    """
    target_binary_dir = os.path.dirname(target_binary)
    target_binary_name = os.path.basename(target_binary)

    symcc_target_binary   = os.path.join('/out/target/symcc/',   target_binary_name)
    vanilla_target_binary = os.path.join('/out/target/vanilla/', target_binary_name)
    cmplog_target_binary  = os.path.join('/out/target/cmplog/',  target_binary_name)

    fuzzer = os.environ["FUZZER"]

    os.environ['AFL_DISABLE_TRIM'] = '1'

    if "afl" in fuzzer:
        os.environ["AFL_SKIP_CPUFREQ"] = "1"
        os.environ["AFL_NO_AFFINITY"] = "1"
        os.environ["AFL_NO_UI"] = "1"
        os.environ["AFL_MAP_SIZE"] = "256000"
        os.environ["AFL_DRIVER_DONT_DEFER"] = "1"
        os.environ["ASAN_OPTIONS"] = ":detect_leaks=0:abort_on_error=1:symbolize=0"

        flag_cmplog = ["-c", cmplog_target_binary]
        sync_flag_master = ["-F", "/findings/symcts/corpus"] if "symcts" else []

        # Start a master and secondary instance of AFL.
        # We need both because of the way SymCC works.
        print('[run_fuzzer] Running %s' % fuzzer)
        afl_fuzzer.prepare_fuzz_environment(input_corpus)

        launch_afl_thread(input_corpus, output_corpus, target_binary,
                          flag_cmplog + ['-M', 'afl-main'] + sync_flag_master)
        time.sleep(2)
        launch_afl_thread(input_corpus, output_corpus, target_binary,
                          flag_cmplog + ['-S', 'havoc'])
        time.sleep(2)

    if "symcts" in fuzzer:
        symcts_bin = "/out/symcts/symcts"
        if "afl" in fuzzer:
            symcts_bin = "/out/symcts/symcts-from_other"

    cmd = [
        symcts_bin,
        '-i', input_corpus,
        '-s', output_corpus,
        '-n', 'symcts',
        '--'
    ]

    if "symqemu" in fuzzer:
        cmd += ["/out/symqemu-x86_64", vanilla_target_binary, "@@"]
    else:
        cmd += [symcc_target_binary, "@@"]

    # Start an instance of SyMCTS.
    # We need to ensure it uses the symbolic version of libc++.
    print('Starting the SyMCTS binary')
    new_environ = os.environ.copy()
    new_environ['LD_LIBRARY_PATH'] = '/out/target/symcc/'
    new_environ['SYMCTS_INHERIT_STDERR'] = '1'
    new_environ['SYMCTS_INHERIT_STDOUT'] = '1'

    print("############ RUNNING: ", " ".join(cmd))
    with subprocess.Popen(cmd, env=new_environ):
        pass