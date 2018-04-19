Remote Connection Manager
=========================

RCM provide you a simple way to do activity on remote access specially to create
tunnelling (local port forwarding).

RCM work with generate bash script that you can manually review before execute.

## Installation

Download from Github.

```
wget -O rcm https://raw.githubusercontent.com/ijortengab/rcm/master/rcm.sh
chmod u+x rcm
```

You can put anywhere in $PATH or make your own alias so you can execute with
command `rcm`.

## How to use

```
Usage: rcm [OPTIONS] external_command (external_command's options and arguments)
  or   rcm [OPTIONS] internal_command [OPTIONS] [ARGUMENTS]

Options
 -p, --interactive           Preview the generated code and ask to execute.
 -i, --interactive           Preview the generated code and ask to execute.
 -q, --quiet                 The generated code will not produce any output.
 -t, --tunnel=HOST           Create tunnel from host (may be more than one).
 -d, --destination=HOST      If tunnel option triggered, the destination must
                             be define to help rcm replace the destination with
                             localhost.
 -h, --help                  Show help and exit.

There are available options specific per internal commands.
Run 'rcm internal_command --help' for more options.
```

External command:

You can use any command that work with remote host. We will create the
tunnel and replace remote host with localhost. External command that officially
support is: `ssh`, `rsync`, `sshfs`.

Internal command:
  - `login`
  - `send-key`
  - `push`
  - `pull`
  - `manage`
  - `open-port`
  - `mount`

## SSH Example

SSH login to destination that require jump in two tunnel:

```
rcm -d guest@virtualmachine.vm -t ijortengab@office.lan -t staff-it@company.com ssh guest@virtualmachine.vm
```

Alternative syntax using special command that easy to read:

```
rcm login guest@virtualmachine.vm via ijortengab@office.lan via staff-it@company.com
```

SSH send command to produce output:

```
rcm -d guest@virtualmachine.vm -t ijortengab@office.lan -t staff-it@company.com ssh guest@virtualmachine.vm echo 1'
```

## RSYNC example

```
rcm -d guest@virtualmachine.vm -t ijortengab@office.lan -t staff-it@company.com rsync -avrP /home/ijortengab/public_html/ guest@virtualmachine.vm:public_html
```

Alternative syntax using special command that easy to read:

```
rcm push guest@virtualmachine.vm via ijortengab@office.lan via staff-it@company.com from /home/ijortengab/public_html/ to public_html
```

```
rcm pull guest@virtualmachine.vm via ijortengab@office.lan via staff-it@company.com from public_html/ to /home/ijortengab/public_html
```

## SSHFS example

Todo.

## Special command

Special command is ignore option: -t, --tunnel=HOST, -d, --destination=HOST.
The destination is set as argument, and the tunnel is declare with argument
'via HOST'.

## Login

```
rcm login guest@virtualmachine.vm via ijortengab@office.lan via staff-it@company.com
```

Options available: -i -q. See `rcm login --help`

## Send Public Key

```
rcm send-key guest@virtualmachine.vm via ijortengab@office.lan via staff-it@company.com
```

Options available: -i -q -l. See `rcm send-key --help`

## Open port

```
rcm open-port guest@virtualmachine.vm via roji@reversrproxy.ui.ac.id via staff-it@company.com
```

```
rcm open-port guest@virtualmachine.vm:5900 via guest@virtualmachine.vm via roji@reversrproxy.ui.ac.id via staff-it@company.com
```
