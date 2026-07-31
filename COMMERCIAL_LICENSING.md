# Commercial licensing

This repository is the community core of Airmonlink Business Manager and is available under GPL-3.0.

A separate commercial licence may be offered for organizations that need proprietary redistribution, private custom modules, managed deployment, support, training, cloud services or alternative licensing terms. Commercial modules and hosted services do not need to be stored in this public repository unless their own licences require it.

## Desktop activation contract

Airmonlink Business Manager 1.3.0+8 preserves the Build 6 activation contract and uses `https://license.airmonlink.com/api/v1`.

- `POST /trial/register` issues one non-renewing trial per device.
- `POST /activate` activates a paid key on the current device.
- `POST /validate` refreshes an active paid licence.
- `POST /deactivate` releases the current device activation.

The desktop application stores the server-issued token and dates in Windows secure storage. Reinstalling, restarting or pressing the trial action again does not create a new trial because the licence server keeps the original device record.
