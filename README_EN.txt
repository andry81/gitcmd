* README_EN.txt
* 2024.07.12
* gitcmd

1. DESCRIPTION
2. LICENSE
3. REPOSITORIES
4. CATALOG CONTENT DESCRIPTION
5. PREREQUISITES
6. EXTERNALS
7. DEPLOY
8. PROJECT CONFIGURATION VARIABLES
9. AUTHOR

-------------------------------------------------------------------------------
1. DESCRIPTION
-------------------------------------------------------------------------------
The Git scripts collection for various user tasks.

-------------------------------------------------------------------------------
2. LICENSE
-------------------------------------------------------------------------------
The MIT license (see included text file "license.txt" or
https://en.wikipedia.org/wiki/MIT_License)

-------------------------------------------------------------------------------
3. REPOSITORIES
-------------------------------------------------------------------------------
Primary:
  * https://github.com/andry81/gitcmd/branches
    https://github.com/andry81/gitcmd.git
First mirror:
  * https://sf.net/p/gitcmd/gitcmd/ci/master/tree
    https://git.code.sf.net/p/gitcmd/gitcmd
Second mirror:
  * https://gitlab.com/andry81/gitcmd/-/branches
    https://gitlab.com/andry81/gitcmd.git

gituserbin:

Primary:
  * https://github.com/andry81/gituserbin
First mirror:
  * https://sf.net/p/gitcmd/gituserbin
Second mirror:
  * https://gitlab.com/andry81/gituserbin

-------------------------------------------------------------------------------
4. CATALOG CONTENT DESCRIPTION
-------------------------------------------------------------------------------

<root>
 |
 +- /`.log`
 |    #
 |    # Log files directory, where does store all log files from all scripts
 |    # including all nested projects.
 |
 +- /`__init__`
 |    #
 |    # Contains special standalone and initialization script(s) to allocate
 |    # basic environment variables and make common preparations.
 |
 +- /`_externals`
 |    #
 |    # Immediate external projects catalog, could not be moved into a 3dparty
 |    # dependencies catalog.
 |
 +- /`_config`
 |  | #
 |  | # Directory with build input configuration files.
 |  |
 |  +- `config.system.vars.in`
 |  |   #
 |  |   # Template file with system set of environment variables
 |  |   # designed to be stored in a version control system.
 |  |
 |  +- `config.0.vars.in`
 |      #
 |      # Template file with user set of environment variables
 |      # designed to be stored in a version control system.
 |
 +- /`_out`
 |  | #
 |  | # Temporary directory with build output.
 |  |
 |  +- /`config`
 |     | #
 |     | # Directory with build output configuration files.
 |     |
 |     +- /`tests`
 |     |  |
 |     |  +- `config.system.vars`
 |     |  |   #
 |     |  |   # Generated temporary file from `*.in` file with set of system
 |     |  |   # customized environment variables to set them locally.
 |     |  |   # Loads before the user customized environment variables file.
 |     |  |   # Loads within `/tests/__init__` scripts.
 |     |  |
 |     |  +- `config.0.vars`
 |     |      #
 |     |      # Generated temporary file with set of user customized
 |     |      # environment variables to set them locally.
 |     |      # Loads after the system customized environment variables file.
 |     |      # Loads within `/tests/__init__` scripts.
 |     |
 |     +- `config.system.vars`
 |     |   #
 |     |   # Generated temporary file from `*.in` file with set of system
 |     |   # customized environment variables to set them locally.
 |     |   # Loads before the user customized environment variables file.
 |     |   # Loads within `/__init__` scripts.
 |     |
 |     +- `config.0.vars`
 |         #
 |         # Generated temporary file from `*.in` file with set of user
 |         # customized environment variables to set them locally.
 |         # Loads after the system customized environment variables file.
 |         # Loads within `/__init__` scripts.
 |
 +- /`scripts`
 |    #
 |    # Scripts root directory.
 |
 +- /`tests`
      #
      # Directory with tests for scripts from the `scripts` directory.

-------------------------------------------------------------------------------
5. PREREQUISITES
-------------------------------------------------------------------------------
Currently used these set of OS platforms, interpreters, modules and
applications to run with or from:

1. OS platforms:

* Windows 7+

* Cygwin 1.5+ or 3.0+ (`.sh` only):
  https://cygwin.com
  - to run scripts under cygwin

* Msys2 20190524+ (`.sh` only):
  https://www.msys2.org
  - to run scripts under msys2

2. Interpreters:

* bash shell 3.2.48+
  - to run unix shell scripts

3. Modules:

NOTE:
  Required ONLY for tests.

* Bash additional modules:

**  tacklelib--bash:
    /_externals/tacklelib/bash/tacklelib/

4. Applications:

* git 2.24+
  https://git-scm.com
  - to run git client
* cygwin cygpath 1.42+
  - to run `bash_tacklelib` script under cygwin
* msys cygpath 3.0+
  - to run `bash_tacklelib` script under msys2
* cygwin readlink 6.10+
  - to run specific bash script functions with `readlink` calls

-------------------------------------------------------------------------------
6. EXTERNALS
-------------------------------------------------------------------------------
NOTE:
  Required ONLY for tests.

See details in `README_EN.txt` in `externals` project:

https://github.com/andry81/externals

-------------------------------------------------------------------------------
7. DEPLOY
-------------------------------------------------------------------------------
NOTE:
  Required ONLY for tests.

To run bash shell scripts (`.sh` file extension) you should copy these scripts:

* /_externals/tacklelib/bash/tacklelib/bash_entry
* /_externals/tacklelib/bash/tacklelib/bash_tacklelib

into the `/bin` directory of your platform.

In pure Linux you have additional step to make scripts executable or readable:

>
sudo chmod ug+x /bin/bash_entry
sudo chmod o+r  /bin/bash_entry
sudo chmod a+r  /bin/bash_tacklelib

-------------------------------------------------------------------------------
8. PROJECT CONFIGURATION VARIABLES
-------------------------------------------------------------------------------
See `README_EN.txt` from `gituserbin` project.

-------------------------------------------------------------------------------
9. AUTHOR
-------------------------------------------------------------------------------
Andrey Dibrov (andry at inbox dot ru)
