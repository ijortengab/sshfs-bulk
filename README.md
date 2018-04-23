Remote Connection Manager
=========================

RCM provide you a simple way to do activity on remote access specially to create
tunnel (local port forwarding).

RCM works with generate bash script that you can manually review before execute.

## Getting Started

Scenario:

You have a virtual machine in PC at Office and your Office has the rack server
that have internet connection.

To access your virtual machine, you must jump to server then jump to your PC and
then jump to virtual machine inside PC.

RCM helps you on that scenario:

```
rcm -t staff@company.com -t ijortengab@pc-office ssh ijortengab@vm
```

or using alternative human readable:

```
rcm login ijortengab@vm via ijortengab@pc-office via staff@company.com
```

RCM can do more to make you easy to work on remote host, such as:

 - sending public key to avoid password prompt
 - synchronize file or directory
 - opening port to access application.

## Installation

Download from Github.

```
wget https://git.io/rcm
chmod u+x rcm
```

You can put `rcm` file anywhere in $PATH or make your own alias so you can
execute with command `rcm`.

```
sudo mv rcm -t /usr/local/bin
```

## How to use

```
Usage: rcm [OPTIONS] origin_command
  or   rcm [OPTIONS] alternative_command

Using rcm without or incomplete arguments will show wizard.

Options
 -p, --preview               Preview the generated code.
 -i, --interactive           Preview the generated code and ask to do.
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

## SSH / LOGIN

SSH login to destination that require jump in two tunnel:

```
rcm -t staff@company.com -t ijortengab@pc-office ssh ijortengab@vm
```

or SSH send command:

```
rcm -t staff@company.com -t ijortengab@pc-office ssh ijortengab@vm /backup.sh
```

Alternative syntax using special command that easy to read:

```
rcm login ijortengab@vm via ijortengab@office.lan via staff-it@company.com
```

SSH send command 

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
