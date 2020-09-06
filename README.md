# caleb9/bind


# Introduction

`Dockerfile` to create a [Docker](https://www.docker.com/) container
image for [BIND](https://www.isc.org/downloads/bind/) DNS server.

BIND is open source software that implements the Domain Name System
(DNS) protocols for the Internet. It is a reference implementation of
those protocols, but it is also production-grade software, suitable
for use in high-volume and high-reliability applications.

This project is a fork of an excellent
[sameersbn/bind](https://github.com/sameersbn/docker-bind). The image
is based on Alpine Linux (instead of Ubuntu in sameersbn/bind) and it
has been stripped of the Webmin Web UI to make it more
lightweight. See
[README](https://github.com/sameersbn/docker-bind/blob/master/README.md)
of the fork base for more information.


## Background

I've been using sameersbn/bind on my Synology NAS as a DNS in my LAN
for some time. After initial configuration I rarely had to open the
Webmin interface for anything else than updating Ubuntu packages. So I
decided to get rid of Webmin and, to make the container even more
lightweight, base it on Alpine Linux instead of Ubuntu.


### Differences / Tweaks

* caleb9/bind image is based on Alpine Linux image instead of Ubuntu
  (as in sameersbn/bind) with Webmin UI completely removed. This
  reduces the image size itself and the amount of memory consumed in
  runtime.
* Installing Bind on Ubuntu is creating a different infrastructure
  than on Alpine. Most notably, the Bind daemon is executed as `bind`
  user (uid: 101) belonging to `bind` group (gid: 101) on Ubuntu,
  while on Alpine the user is `named` (uid: 100) and it belongs to
  `named` group (gid: 101).
* Default, empty config file `/etc/bind/named.conf` is added if it
  does not exist - this makes it possible to run the container with
  zero configuration and it just works.


# Getting started

## Quickstart

### Testing

You can test if the DNS works at all by running the container without
any mounted config directory:

```
$ docker run --rm --name bind -d --publish 8053:53/tcp --publish 53:53/udp caleb9/bind:latest
```

Use `nslookup` to test if it can resolve e.g. `google.com` domain
name:

```
$ nslookup -port=8053 google.com localhost
Server:         localhost
Address:        127.0.0.1#8053

Non-authoritative answer:
Name:   google.com
Address: 172.217.20.46
Name:   google.com
Address: 2a00:1450:400f:806::200e
```

Stop the container when done:

```
$ docker stop bind
```

### Running as DNS server

The following command will execute Bind as an actual local DNS server
by binding default DNS query port 53 on host machine to the
container. To be able to edit the configuration and preserve it
between restarts, a directory must be mounted as `/data` in the
container (here for instance I use `/docker/caleb9-bind` for that):

```
docker run \
  --volume /docker/caleb9-bind:/data \
  --name bind \
  --detach \
  --restart=always \
  --publish 53:53/tcp \
  --publish 53:53/udp \
  caleb9/bind:latest
```

See the next section if you were previously running sameersbn/bind and
would like to reuse the configuration.


## Migrating from sameersbn/bind

You can re-use sameersbn/bind configuration when running
caleb9/bind. There are two steps you need to take to migrate: fix
ownership of the mounted files, and change path to default zone hints
within the container.


### Fixing configuration ownership

Let's assume you were mounting `/docker/sameersbn-bind` directory as
`/data` in the container to make configuration persistent. The
directory probably looks similar to this:

```
$ tree /docker/sameersbn-bind
/docker/sameersbn-bind
├── bind
│   ├── etc
│   │   ├── bind.keys
│   │   ├── db.0
│   │   ├── db.127
│   │   ├── db.255
│   │   ├── db.empty
│   │   ├── db.local
│   │   ├── named.conf
│   │   ├── named.conf.default-zones
│   │   ├── named.conf.local
│   │   ├── named.conf.options
│   │   ├── rndc.key
│   │   └── zones.rfc1918
│   └── lib
│       └── my-zone.com.hosts
└── webmin
    └── [snip!]
```

The contents of that directory are owned by `100:101` (`bind:bind` on
Ubuntu) because the `entrypoint.sh` script in sameersbn/bind runs
`chown` on it to make it accessible to Bind daemon. Since the uid of
the `named` user is `100` (not `101`) on Alpine, you should change the
ownership before mounting it in `caleb9/bind`.

1. It's a good idea to copy the configuration - in case something
   doesn't work you can always get back to sameersbn/bind. Run the
   following `$ cp -r /docker/sameersbn-bind /docker/caleb9-bind`.
2. Now change the ownership: `$ chown -R 100:101
   /docker/caleb9-bind/*`

You can also remove the `webmin` sub-directory as it is not used: `$
rm -r /docker/caleb9-bind/webmin`.

### Fixing root.hints path

Installing Bind on Ubuntu creates a `/usr/share/dns/` directory
containing `root.hints` and few other files needed by the daemon. The
path is specified in the root zone configuration, near the top of
`named.conf.default-zones` file:

```
$ head -n 5 /docker/sameersbn-bind/bind/etc/named.conf.default-zones
// prime the server with knowledge of the root servers
zone "." {
        type hint;
        file "/usr/share/dns/root.hints";
};
```

On Alpine, this file is called
`/usr/share/dns-root-hints/named.root`. You need to change the path in
`named.conf.default-zones` file to accommodate for this. Use your
favorite editor to change the path so it looks as following:

```
$ head -n 5 /docker/caleb9-bind/bind/etc/named.conf.default-zones 
// prime the server with knowledge of the root servers
zone "." {
        type hint;
        file "/usr/share/dns-root-hints/named.root";
};

```

To change it in place you can use the following command:

```
sed -i 's/\/usr\/share\/dns\/root.hints/\/usr\/share\/dns-root-hints\/named.root/g' \
    /docker/caleb9--bind/bind/etc/named.conf.default-zones
```


## Roadmap / TODO

* This README should be expanded with more information, probably
  copied from `sameersbn/bind` source.
* CI/CD would be great to set up, with Bind version being used as
  image tag (again, similarly as in `sameersbn/bind`)
* Changelog should be added.
* It would be nice to create separate image containing Webmin based on
  Alpine if possible.
