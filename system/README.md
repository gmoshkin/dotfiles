Initial setup. `enable` to make it automatically started on system boot. `start` to
start immediately.

```bash
for SERVICE in *.service {
    sudo cp "$SERVICE" /etc/systemd/system
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE"
    sudo systemctl start "$SERVICE"
}
```

To update the service if the unit has changed.
```bash
for SERVICE in *.service {
    sudo systemctl stop "$SERVICE"
    sudo cp "$SERVICE" /etc/systemd/system
    sudo systemctl daemon-reload
    sudo systemctl start "$SERVICE"
}
```
