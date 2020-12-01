ecosis.service is a sample script that can be used to register systemd cmds

## Systemd Files

After placing file in ecosis-systemd (and making any required edits to path)

```
cd /opt/ecosis-systemd
sudo systemctl enable ecosis.service
```

Then

```bash
> sudo service [start|stop] ecosis
```

