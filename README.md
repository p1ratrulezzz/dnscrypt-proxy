# dnscrypt-proxy

Minimal multi-arch image of [dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) for amd64 and arm64. Intended to run as a standalone DNSSEC-validating resolver, including on MikroTik RouterOS containers.

Images:

- `ghcr.io/p1ratrulezzz/dnscrypt-proxy:latest` — built from `master`
- `ghcr.io/p1ratrulezzz/dnscrypt-proxy:<version>` — built from a git tag

The process starts as root so it can bind port 53, then drops to the `dnscrypt` user when `user_name` is set. Config is not baked into the image; mount it at `/config/dnscrypt-proxy.toml`.

## Config

`listen_addresses` must be `0.0.0.0`, not `127.0.0.1`, or nothing outside the container can reach it.

```toml
listen_addresses = ['0.0.0.0:53']
user_name = 'dnscrypt'
require_dnssec = true
```

If the runtime cannot bind a privileged port (`bind: permission denied`), listen on `5353` and forward external port 53 to it.

## MikroTik

This matches a router that is itself bridged to an upstream router. The container lives on its own subnet. The upstream router does not know that subnet, so outbound traffic must be masqueraded. Clients do not use `10.10.4.2` directly; they query a second address on this MikroTik, and dst-nat sends port 53 to the container.

Replace `192.168.88.53/24` and `bridge` with an address and LAN interface that exist on this router.

```routeros
/interface veth
add name=veth-dns address=10.10.4.2/24 gateway=10.10.4.1

/interface bridge
add name=br-containers

/ip address
add address=10.10.4.1/24 interface=br-containers
add address=192.168.88.53/24 interface=bridge

/interface bridge port
add bridge=br-containers interface=veth-dns

/ip firewall nat
add chain=srcnat action=masquerade src-address=10.10.4.0/24
add chain=dstnat action=dst-nat dst-address=192.168.88.53 protocol=udp dst-port=53 \
    to-addresses=10.10.4.2 to-ports=53
add chain=dstnat action=dst-nat dst-address=192.168.88.53 protocol=tcp dst-port=53 \
    to-addresses=10.10.4.2 to-ports=53

/ip firewall filter
add chain=forward action=accept dst-address=10.10.4.2 protocol=udp dst-port=53
add chain=forward action=accept dst-address=10.10.4.2 protocol=tcp dst-port=53
add chain=input action=accept src-address=10.10.4.0/24
```

The bridge address must be `/24`. A `/32` installs a route only to `10.10.4.1`, so the container at `10.10.4.2` never becomes a neighbor and cannot ping its gateway.

Mount the config, then pull the image. `registry-url` is the registry only; do not repeat `ghcr.io` in `remote-image`.

```routeros
/container mounts
add name=dns-config src=disk1/dnscrypt/config dst=/config

/container config
set registry-url=https://ghcr.io tmpdir=disk1/tmp

/container
add remote-image=p1ratrulezzz/dnscrypt-proxy:latest interface=veth-dns \
    root-dir=disk1/dnscrypt name=dnscrypt mountlists=dns-config \
    logging=yes start-on-boot=yes
/container start dnscrypt
```

Point clients at `192.168.88.53`, not at the upstream router and not at `10.10.4.2`. Check from a LAN host, not from the router: packets generated on RouterOS do not pass through dst-nat.

```text
nslookup cloudflare.com 192.168.88.53
```

RouterOS does not run a Docker `HEALTHCHECK`. A query to `192.168.88.53` is the health check.
