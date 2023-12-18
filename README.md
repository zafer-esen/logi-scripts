# Overview

A bunch of scripts for automating the running of experiments on a server (mainly intended for logicrunch).

`config.sh`: Set this up first.

`run_experiments.sh`: For running experiments. Passing `-f` as argument disables user prompts and forces default options.

`cancel_runs.sh`: Cancels the last set of experiments. Use this if you made a mistake to quickly cancel the _last_ started job.

`pull_logdir.sh`: Pulls remote log dir to local log dir (defined in `config.sh`).

`push_logdir.sh`: Pushes local log dir to remote log dir. This first backs up remote log dir, and copies everything over to remote.

`analyze_logs.sh`: After remote log dir is pulled to local, this script will first convert `.log1` files to YAML in the _latest_ log directory, then call `yml2stats` to print the analysis results.