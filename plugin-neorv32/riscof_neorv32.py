import os
import re
import shutil
import subprocess
import shlex
import logging
import random
import string
from string import Template
import sys

import riscof.utils as utils
import riscof.constants as constants
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class neorv32(pluginTemplate):
    __model__ = "neorv32"

    #TODO: please update the below to indicate family, version, etc of your DUT.
    __version__ = "INITIAL"

    def __init__(self, *args, **kwargs):
        sclass = super().__init__(*args, **kwargs)

        config = kwargs.get('config')

        # If the config node for this DUT is missing or empty. Raise an error. At minimum we need
        # the paths to the ispec and pspec files
        if config is None:
            print("Please enter input file paths in configuration.")
            raise SystemExit(1)

        # In case of an RTL based DUT, this would be point to the final binary executable of your
        # test-bench produced by a simulator (like verilator, vcs, incisive, etc). In case of an iss or
        # emulator, this variable could point to where the iss binary is located. If 'PATH variable
        # is missing in the config.ini we can hardcode the alternate here.
        self.dut_exe = os.path.join(config['PATH'] if 'PATH' in config else "","neorv32")

        # Number of parallel jobs that can be spawned off by RISCOF
        # for various actions performed in later functions, specifically to run the tests in
        # parallel on the DUT executable. Can also be used in the build function if required.
        self.num_jobs = str(config['jobs'] if 'jobs' in config else 1)

        # Path to the directory where this python file is located. Collect it from the config.ini
        self.pluginpath=os.path.abspath(config['pluginpath'])

        # Collect the paths to the  riscv-config absed ISA and platform yaml files. One can choose
        # to hardcode these here itself instead of picking it from the config.ini file.
        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])

        #We capture if the user would like the run the tests on the target or
        #not. If you are interested in just compiling the tests and not running
        #them on the target, then following variable should be set to False
        if 'target_run' in config and config['target_run']=='0':
            self.target_run = False
        else:
            self.target_run = True

        # Return the parameters set above back to RISCOF for further processing.
        return sclass

    def initialise(self, suite, work_dir, archtest_env):

       # capture the working directory. Any artifacts that the DUT creates should be placed in this
       # directory. Other artifacts from the framework and the Reference plugin will also be placed
       # here itself.
       self.work_dir = work_dir

       # capture the architectural test-suite directory.
       self.suite_dir = suite

       # Note the march is not hardwired here, because it will change for each
       # test. Similarly the output elf name and compile macros will be assigned later in the
       # runTests function
       self.compile_cmd = 'riscv{1}-unknown-elf-gcc -march={0} \
         -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -g\
         -T '+self.pluginpath+'/env/link.ld\
         -I '+self.pluginpath+'/env/\
         -I ' + archtest_env + ' {2} -o {3} {4}'

       # prepare simulation (GHDL)
       execute = 'sh ./sim/ghdl_setup.sh'
       logger.debug('DUT executing ' + execute)
       utils.shellCommand(execute).run()

    def build(self, isa_yaml, platform_yaml):

      # load the isa yaml as a dictionary in python.
      ispec = utils.load_yaml(isa_yaml)['hart0']

      # capture the XLEN value by picking the max value in 'supported_xlen' field of isa yaml. This
      # will be useful in setting integer value in the compiler string (if not already hardcoded);
      self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')

      # for spike start building the '--isa' argument. the self.isa is dutnmae specific and may not be
      # useful for all DUTs
      self.isa = 'rv' + self.xlen
      if "I" in ispec["ISA"]:
          self.isa += 'i'
      if "M" in ispec["ISA"]:
          self.isa += 'm'
      if "C" in ispec["ISA"]:
          self.isa += 'c'

      self.compile_cmd = self.compile_cmd+' -mabi='+('lp64 ' if 64 in ispec['supported_xlen'] else 'ilp32 ')

      # Override default exception relocation list - remove EBREAK exception since NEORV32 clears MTVAL
      # when encountering this type of exception (permitted by RISC-V priv. spec.)
      print("<plugin-neorv32> overriding default SET_REL_TVAL_MSK macro (removing BREAKPOINT exception)")
      neorv32_override = ' \"-DSET_REL_TVAL_MSK=(('
      neorv32_override = neorv32_override+'(1<<CAUSE_MISALIGNED_FETCH) | '
      neorv32_override = neorv32_override+'(1<<CAUSE_FETCH_ACCESS)     | '
#     neorv32_override = neorv32_override+'(1<<CAUSE_BREAKPOINT)       | '
      neorv32_override = neorv32_override+'(1<<CAUSE_MISALIGNED_LOAD)  | '
      neorv32_override = neorv32_override+'(1<<CAUSE_LOAD_ACCESS)      | '
      neorv32_override = neorv32_override+'(1<<CAUSE_MISALIGNED_STORE) | '
      neorv32_override = neorv32_override+'(1<<CAUSE_STORE_ACCESS)     | '
      neorv32_override = neorv32_override+'(1<<CAUSE_FETCH_PAGE_FAULT) | '
      neorv32_override = neorv32_override+'(1<<CAUSE_LOAD_PAGE_FAULT)  | '
      neorv32_override = neorv32_override+'(1<<CAUSE_STORE_PAGE_FAULT)   '
      neorv32_override = neorv32_override+') & 0xFFFFFFFF)\" '
      self.compile_cmd = self.compile_cmd+neorv32_override

#The following template only uses shell commands to compile and run the tests.

    def runTests(self, testList):

      # we will iterate over each entry in the testList. Each entry node will be referred to by the
      # variable testname.
      for testname in testList:

          logger.debug('Running Test: {0} on DUT'.format(testname))
          # for each testname we get all its fields (as described by the testList format)
          testentry = testList[testname]

          # we capture the path to the assembly file of this test
          test = testentry['test_path']

          # capture the directory where the artifacts of this test will be dumped/created.
          test_dir = testentry['work_dir']

          # name of the elf file after compilation of the test
          elf = 'main.elf'

          # name of the signature file as per requirement of RISCOF. RISCOF expects the signature to
          # be named as DUT-<dut-name>.signature. The below variable creates an absolute path of
          # signature file.
          sig_file = os.path.join(test_dir, self.name[:-1] + ".signature")

          # for each test there are specific compile macros that need to be enabled. The macros in
          # the testList node only contain the macros/values. For the gcc toolchain we need to
          # prefix with "-D". The following does precisely that.
          compile_macros= ' -D' + " -D".join(testentry['macros'])

          # collect the march string required for the compiler
          marchstr = testentry['isa'].lower()

          # substitute all variables in the compile command that we created in the initialize
          # function
          cmd = self.compile_cmd.format(marchstr, self.xlen, test, elf, compile_macros)

          # just a simple logger statement that shows up on the terminal
          logger.debug('Compiling test: ' + test)

          # the following command spawns a process to run the compile command. Note here, we are
          # changing the directory for this command to that pointed by test_dir. If you would like
          # the artifacts to be dumped else where change the test_dir variable to the path of your
          # choice.
          utils.shellCommand(cmd).run(cwd=test_dir)


          # NEORV32-specific hardware configuration (using lots of shell stuff)

          # copy ELF to sim folder
          execute = 'cp -f {0}/{1} ./sim/{1}'.format(test_dir, elf)
          logger.debug('DUT executing ' + execute)
          utils.shellCommand(execute).run()

          # convert to HEX memory initialization file
          execute = 'make -C ./sim clean main.hex'
          logger.debug('DUT executing ' + execute)
          utils.shellCommand(execute).run()

          # prepare run of GHDL simulation
          execute = 'sh sim/ghdl_run.sh'
          # set memory size
          exe_stats = os.stat("sim/main.hex")
#         print(exe_stats.st_size)
          execute += ' -gMEM_SIZE=' + str(exe_stats.st_size)
          # set ISA extensions
          if "rv32im" in marchstr:
              execute += ' -gRISCV_M=true'
          # 'privilege' tests also require C extension
          if "rv32ic" in marchstr or "privilege" in test:
              execute += ' -gRISCV_C=true'
          if "rv32izba" in marchstr or "rv32izbb" in marchstr or "rv32izbc" in marchstr or "rv32izbs" in marchstr:
              execute += ' -gRISCV_B=true'
          logger.debug('DUT executing ' + execute)
#         print(execute)
          utils.shellCommand(execute).run()

          # debug output
          print(f"{test=}")

          # copy resulting signature file
          execute = 'cp -f ./sim/DUT-neorv32.signature {0}/.'.format(test_dir)
          logger.debug('DUT executing ' + execute)
          utils.shellCommand(execute).run()


      # if target runs are not required then we simply exit as this point after running all
      # the makefile targets.
      if not self.target_run:
          raise SystemExit
