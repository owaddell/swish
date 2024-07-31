## Running as a Service

### Linux

This example creates a swish-example-service that runs in the `systemd` user instance.
The service is a simple web server listening on port 8000 that hosts dynamic pages:
 - `index.ss` returns HTML containing the output of `(pps)`, which shows information about Swish light-weight processes that are live.
 - `crash.ss` "crashes" the application by calling `application:shutdown`; we can use this to see that the service restarts the server.
 - `query.ss` returns HTML containing the result of a simple database query against the Swish system log; we can use this to see the service respond after we suspend and resume a laptop running the service.

This example shows how we can extend the default application supervision tree by updating the value of `app-sup-spec` before we call `app:start`. It also shows how we can specify an in-memory `log-file` to avoid writing the Swish system log database to disk.

Build the application:

```
$ make
```

Install the `systemd` unit file:
```
$ mkdir -p ${HOME}/.config/systemd/user
$ /bin/cat <<EOF > ${HOME}/.config/systemd/user/swish-service-example.service
[Unit]
Description=A simple user-mode swish service

[Service]
Type=simple
ExecStart=${PWD}/swish-service-example /SERVICE
WorkingDirectory=${PWD}
Restart=always

[Install]
WantedBy=default.target
EOF
```

Enable the new service:
```
$ systemctl --user enable swish-service-example
```

Start the service:
```
$ systemctl --user start swish-service-example
```

Try it out. Expect `(pps)` output:
```
$ curl -s http://localhost:8000
```

Query the `<statistics>` table. Expect a "startup" message:
```
$ curl -s http://localhost:8000/query | tidy -iq --tidy-mark no
```
If the service has been running a while, you may also see "update" messages.

Suspend and resume your machine, then re-query the `<statistics>` table.
Expect a "suspend" message and a "resume" message:
```
$ curl -s http://localhost:8000/query | tidy -iq --tidy-mark no
```

Try crashing the service and check that it restarts:
```
$ curl -s http://localhost:8000/crash
$ curl -s http://localhost:8000
```

Stop the service:
```
$ systemctl --user stop swish-service-example
```

Disable the service:
```
$ systemctl --user disable swish-service-example
```

Uninstall the service:
```
$ rm ${HOME}/.config/systemd/user/swish-service-example.service
```

### Windows

Build the application:

```
$ make
```

Copy the DLLs:

```
$ cp ../../build/release/bin/*.dll .
$ cp ${CHEZ_SCHEME:?}/bin/a6nt/bin/csv964.dll .
```

#### In a shell invoked with `Run as administrator` in the example/service directory

Install the service:

```
$ sc create swish-service-example start= demand binpath= "`cygpath -aw ./swish-service-example.exe` /SERVICE swish-service-example `cygpath -aw ./service.log`" depend= tcpip DisplayName= "Swish Service Example"
$ sc description swish-service-example "Swish Service Example"
```

Start the service:

```
$ net start swish-service-example
```

Uninstall the service:

```
$ net stop swish-service-example
$ sc delete swish-service-example
```

