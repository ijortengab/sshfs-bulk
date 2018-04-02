Remote Connection Manager
=========================

## Getting Started

RCM is easy for you to connect SSH.

```
rcm ssh ijortengab@ijortengab.id via proxy@vpn.company.com
```

It equals to...

```
echo -e "Create tunnel."
ssh -fN proxy@vpn.company.com -L 21200:ijortengab.id:22
echo -e "Connect ssh."

```


