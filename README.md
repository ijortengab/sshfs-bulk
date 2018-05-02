

Remote Connection Manager
=========================

RCM provide you a simple way to do activity on remote access.

RCM works with generate bash script that you can manually preview before execute.

## Getting Started

Scenario:

You have a virtual machine inside your PC at Office. Your Office has the rack
server that have IP Public.

To access your virtual machine, you must jump to server then jump to your PC
and then jump to virtual machine.

RCM helps you on that scenario:

```
rcm login guest@vm via ijortengab@office:2222 via staff@company.com:80
```

Command above helps you to generate bash script like this:

```
ssh -J staff@company.com:80,ijortengab@office:2222 guest@vm
```

or this complicated one:

```
ssh -p 80 -fN -L 50000:office:2222 staff@company.com
ssh -p 50000 -fN -L 50001:vm:22 ijortengab@localhost
ssh -p 50001 guest@localhost
```

RCM can do more to make you easy to work on remote host, such as:

- sending public key to avoid password prompt
- opening resource  (port on remote host) to access it in localhost

Coming soon:

- manage host to easy re-use instead of save it in plain text
- synchronize file or directory (rsync)
- mount remote directory in local (sshfs)

## Installation

Download from Github.

```
wget https://git.io/rcm
chmod a+x rcm
```

You can put `rcm` file anywhere in $PATH or make your own alias so you can
execute with command `rcm`.

```
sudo mv rcm -t /usr/local/bin
```

## How to use

**General**

```
Usage: rcm [OPTIONS] command [ROUTE]

Options:
 -p, --preview               Preview the generated code.
 -q, --quiet                 The generated code will not produce any output.
 -s, --style=STYLE           Default to 'auto'. How template of code that
                             you prefer to generated. Option available is:
                             - 'jump' use ProxyJump ssh -J
                             - 'tunnel' use Local Port Forwarding ssh -L

Example of ROUTE:

  guest@vm via ijortengab@office:2222 via staff@company.com:80

which
- guest@vm                  The destination
- ijortengab@office:2222    The jump host to guest@vm
- staff@company.com:80      The jump host to ijortengab@office:2222
Your terminal will access staff@company.com:80 first.
```

**Login**

```
Usage: rcm login ROUTE

Ssh login to destination in ROUTE.

Example:
  rcm login guest@vm via ijortengab@office:2222 via staff@company.com:80

Specific options:
  None
```

**Send Public Key**

```
Usage: rcm send-key ROUTE

Ssh command to sending your public key to entire address or destinaton only
in ROUTE. This help you to avoid input password for the next login.

Example:
  rcm send-key guest@vm via ijortengab@office:2222 via staff@company.com:80

Specific options:
  -l, --last-one             Send public key only to destination. Default to
                             entire address in ROUTE.
  -k, --public-key           Specify the public key path. Default to
                             ~/.ssh/id_rsa.pub, ~/.ssh/id_dsa.pub,
                             ~/.ssh/id_ecdsa.pub, ~/.ssh/id_ed25519.pub
```

**Open port**

```
Usage: rcm open-port ROUTE
  or   rcm open-port PORT ROUTE

Ssh command to access remote resource in localhost port.

Example:
  Open port SSH, to access destination with WinSCP.
    rcm open-port vm via ijortengab@office via staff@company.com

  Open port VNC of destination direct from last tunnel without SSH.
    rcm open-port vm:5900 via ijortengab@office via staff@company.com

  Open port VNC of destination after SSH login to last destination.
    rcm open-port 5900 guest@vm via ijortengab@office via staff@company.com

Specific options:
  -n, --number               Set your own localhost port number. Default to
                             random.
```
