# Erlang on Alpine Linux

This Dockerfile provides a full installation of Erlang on Alpine, intended for running Erlang releases,
so it has no build tools installed. The Erlang installation is provided so one can avoid cross-compiling
releases. The caveat of course is if one has NIFs which require a native compilation toolchain, but that is
left as an exercise for the reader.

## Usage

NOTE: This image sets up a `default` user, with home set to `/opt/app` and owned by that user. The working directory
is also set to `$HOME`. It is highly recommended that you add a `USER default` instruction to the end of your
Dockerfile so that your app runs in a non-elevated context.

To boot straight to a prompt in the image:

```
$ docker run --rm -it --user=root bitwalker/alpine-erlang erl
Erlang/OTP 20 [erts-9.2] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false]

Eshell V9.2  (abort with ^G)
1>
BREAK: (a)bort (c)ontinue (p)roc info (i)nfo (l)oaded
       (v)ersion (k)ill (D)b-tables (d)istribution
a
```

Extending for your own application:

```dockerfile
FROM bitwalker/alpine-erlang:20.3.1

# Set exposed ports
EXPOSE 5000
ENV PORT=5000

ENV MIX_ENV=prod

ADD yourapp.tar.gz ./

USER default

ENTRYPOINT ["./bin/yourapp"]
CMD ["foreground"]
```

## License

MIT
