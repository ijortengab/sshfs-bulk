Remote Connection Manager
=========================

RCM provide you a simple way to do activity on remote access specially to create
tunnelling (local port forwarding).

## Getting Started

RCM is make it easy for you to connect SSH.

```
rcm ssh ijortengab@ijortengab.id via proxy@vpn.company.com
```

It equals to...

```
ssh -fN proxy@vpn.company.com -L 50000:ijortengab.id:22
ssh ijortengab@localhost -p 50000
```

Again...

```
rcm ssh ijortengab@ijortengab.id via user@gateway.com via proxy@vpn.company.com
```

It equals to...

```
ssh -fN proxy@vpn.company.com -L 50001:gateway.com:22
ssh -fN user@localhost -p 50001 -L 50000:ijortengab.id:22
ssh ijortengab@localhost -p 50000
```

## More example

RCM is make it easy for you to send public key to server.

```
rcm send-key ijortengab@ijortengab.id via user@gateway.com via proxy@vpn.company.com
```
